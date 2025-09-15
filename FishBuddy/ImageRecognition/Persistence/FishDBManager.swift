//
//  FishDBManager.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/5.
//

import SQLite
import Foundation

/// 快捷的取得 Embedding 資料：使用 json
actor EmbeddingStore {
    /// 共用實例
    static let shared = EmbeddingStore()
    /// 資料庫
    var fishDB: FishDB?
    /// 讀取的 taxonItem 暫存
    var taxonItemCache: [TaxonItem] = []
    /// In-memory 向量索引快取（只建一次，除非資料有變動）
    private var indexCache: InMemoryVectorIndex?
    /// 當前索引的維度；避免用錯模型維度
    private var indexDim: Int = 0
    
    init() {
        do {
            let fm = FileManager.default
            let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dest = docs.appendingPathComponent("catalog.sqlite")

            // 第一次啟動：若 Documents 裡沒有 DB，嘗試從 bundle 複製預載檔
            if !fm.fileExists(atPath: dest.path) {
                if let src = Bundle.main.url(forResource: "catalog", withExtension: "sqlite") {
                    try fm.copyItem(at: src, to: dest)
                    print("已從 bundle 複製 DB 至:", dest.path)
                } else {
                    print("⚠️ bundle 內找不到 catalog.sqlite，將在首次啟動時以 DDL 建立空 schema。")
                }
            }

            self.fishDB = try FishDB(path: dest.path)
            print("DB 路徑在:", dest.path)
        } catch {
            print("資料庫初始化失敗: \(error)")
        }
    }
    
    /// 取得（或建立）InMemoryVectorIndex：會從 SQLite 載入全部向量，打包成 N×D 矩陣，只做一次
    /// - Parameter dim: 向量維度（例如 512 或 768）
    /// - Returns: 可重用的 InMemoryVectorIndex 實例
    func getIndex(dim: Int) async throws -> InMemoryVectorIndex {
        if let idx = indexCache, indexDim == dim {
            return idx
        }
        guard let fishDB else { throw NSError(domain: "EmbeddingStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "FishDB 未初始化"]) }
        
        // 從 SQLite 讀取全部資料列
        var items: [TaxonItem]
         
        // 加入暫存機制，不用每次都讀取資料庫
        if taxonItemCache.isEmpty {
            items = try fishDB.loadAll()
            
            if taxonItemCache.isEmpty {
                taxonItemCache = items
            }
        } else {
            items = taxonItemCache
        }
        // 以 dim 檢查每筆維度
        guard items.allSatisfy({ $0.embedding.count == dim }) else {
            throw NSError(domain: "EmbeddingStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "向量維度不一致或與 dim 不符"]) }
        let idx = InMemoryVectorIndex(items: items, dim: dim)
        indexCache = idx
        indexDim = dim
        return idx
    }
}

final class FishDB {
    /// 資料庫
    private let db: Connection

    // 以預處理時相同的 DDL 作為後援（僅在找不到任何表時才執行）
    private static let schemaDDL: String = {
        return """
        PRAGMA journal_mode=OFF;
        PRAGMA synchronous=OFF;
        BEGIN IMMEDIATE;
        CREATE TABLE species (
          taxon_id INTEGER PRIMARY KEY,
          scientific_name TEXT,
          common_name TEXT,
          rank TEXT,
          slug TEXT
        );
        CREATE TABLE photos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taxon_id INTEGER NOT NULL,
          url TEXT NOT NULL,
          license_code TEXT,
          attribution TEXT,
          source TEXT
        );
        CREATE TABLE embeddings (
          taxon_id INTEGER PRIMARY KEY,
          dim INTEGER NOT NULL,
          vec BLOB NOT NULL
        );
        CREATE TABLE species_meta (
          taxon_id INTEGER PRIMARY KEY,
          meta_json TEXT
        );
        CREATE TABLE embedding_meta (
          taxon_id INTEGER PRIMARY KEY,
          meta_json TEXT
        );
        CREATE INDEX idx_species_sci ON species(scientific_name);
        CREATE INDEX idx_photos_taxon ON photos(taxon_id);
        COMMIT;
        """
    }()

    /// 若資料庫是新建且沒有任何預期的表，執行 DDL 建立 schema
    private func bootstrapIfEmpty() throws {
        let count = try db.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('species','photos','embeddings','species_meta','embedding_meta');") as! Int64
        if count == 0 {
            // SQLite.swift 的 db.run 不支援一次執行多條語句；需要逐條執行
            let statements = FishDB.schemaDDL
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for sql in statements {
                try db.run(sql)
            }

            let newCount = try db.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('species','photos','embeddings','species_meta','embedding_meta');") as! Int64
            print("✅ 已執行 bootstrap DDL，建表完成（表數=\(newCount)）")
        }
    }

    init(path: String) throws {
        // 先確保檔案存在：若文件不存在，SQLite.swift 會建立空白 DB，導致後續查詢找不到表
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            print("⚠️ 指定路徑尚無 DB 檔，將建立空白資料庫並以 DDL 建立 schema: \(path)")
        }
        db = try Connection(path)
        try bootstrapIfEmpty()
    }

    // 小工具：Float 陣列 <-> Data(BLOB)
    // [Float32] -> Blob
    private func floatsToBlob(_ v: [Float32]) -> SQLite.Blob {
        v.withUnsafeBufferPointer { buf in
            let raw = UnsafeRawBufferPointer(buf)
            return SQLite.Blob(bytes: Array(raw))
        }
    }

    // Blob -> [Float32]
    private func blobToFloats(_ b: SQLite.Blob) -> [Float32] {
        b.bytes.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
    }

    // 讀取所有資料
    func loadAll() throws -> [TaxonItem] {
        // === 基礎表（species） ===
        let speciesT = Table("species")
        let s_taxon  = SQLite.Expression<Int>("taxon_id")
        let s_sci    = SQLite.Expression<String?>("scientific_name")
        let s_common = SQLite.Expression<String?>("common_name")
        let s_slug   = SQLite.Expression<String?>("slug")

        // === 關聯表（photos） ===
        let photosT  = Table("photos")
        let p_taxon  = SQLite.Expression<Int>("taxon_id")
        let p_url    = SQLite.Expression<String?>("url")
        let p_lic    = SQLite.Expression<String?>("license_code")
        let p_attr   = SQLite.Expression<String?>("attribution")
        let p_src    = SQLite.Expression<String?>("source")

        // === 關聯表（embeddings） ===
        let embedsT  = Table("embeddings")
        let e_taxon  = SQLite.Expression<Int>("taxon_id")
        let e_dim    = SQLite.Expression<Int>("dim")
        let e_vec    = SQLite.Expression<SQLite.Blob>("vec")

        // === 關聯表（meta JSON） ===
        let sMetaT   = Table("species_meta")
        let sm_taxon = SQLite.Expression<Int>("taxon_id")
        let sm_json  = SQLite.Expression<String?>("meta_json")

        let eMetaT   = Table("embedding_meta")
        let em_taxon = SQLite.Expression<Int>("taxon_id")
        let em_json  = SQLite.Expression<String?>("meta_json")

        // 1) 撈全部 species
        let speciesRows = try Array(db.prepare(speciesT.select(s_taxon, s_sci, s_common, s_slug)))

        // 2) 撈 photos 並分組
        var photosMap: [Int: [Photo]] = [:]
        for r in try db.prepare(photosT.select(p_taxon, p_url, p_lic, p_attr, p_src)) {
            let tid = r[p_taxon]
            let photo = Photo(
                url: r[p_url] ?? "",
                licenseCode: r[p_lic],
                attribution: r[p_attr],
                source: r[p_src]
            )
            photosMap[tid, default: []].append(photo)
        }

        // 3) 撈 embeddings（BLOB → [Float]）
        var embedMap: [Int: [Float]] = [:]
        for r in try db.prepare(embedsT.select(e_taxon, e_dim, e_vec)) {
            let tid = r[e_taxon]
            let vec32: [Float32] = blobToFloats(r[e_vec])
            embedMap[tid] = vec32.map { Float($0) }
        }

        // 4) 撈 meta（JSON 反序列化）
        let decoder = JSONDecoder()
        var speciesMetaMap: [Int: Meta] = [:]
        for r in try db.prepare(sMetaT.select(sm_taxon, sm_json)) {
            if let js = r[sm_json],
               let data = js.data(using: .utf8),
               let meta = try? decoder.decode(Meta.self, from: data) {
                speciesMetaMap[r[sm_taxon]] = meta
            }
        }
        var embedMetaMap: [Int: EmbeddingMeta] = [:]
        for r in try db.prepare(eMetaT.select(em_taxon, em_json)) {
            if let js = r[em_json],
               let data = js.data(using: .utf8),
               let meta = try? decoder.decode(EmbeddingMeta.self, from: data) {
                embedMetaMap[r[em_taxon]] = meta
            }
        }

        // 5) 組裝 TaxonItem
        return speciesRows.map { r in
            let tid = r[s_taxon]
            return TaxonItem(
                taxonId: tid,
                scientificName: r[s_sci],
                commonName: r[s_common],
                slug: r[s_slug],
                photos: photosMap[tid],
                meta: speciesMetaMap[tid],
                embedding: embedMap[tid] ?? [],
                embeddingMeta: embedMetaMap[tid]
            )
        }
    }
}

import Accelerate

final class InMemoryVectorIndex {
    /// 向量維度（embedding 的維度 D）
    let dim: Int

    /// 各資料列的 id 與名稱：
    /// 保留在獨立的連續陣列，避免把字串塞進矩陣資料結構造成額外的間接取用（pointer chasing）。
    private(set) var ids: [String] = []
    private(set) var names: [String] = []

    /// 連續矩陣（N × D，row-major）
    /// - 為什麼要用一維 [Float]？Swift 的 `Float` 就是 Float32，連續記憶體對 CPU cache 友善、能吃到 SIMD。
    /// - row-major：第 i 列從 index `i*dim` 開始連續擺 D 個元素，適合做「矩陣×向量」的掃描。
    /// - 對比 [[Float]]：雙層陣列會有多個非連續的 buffer，逐列 dot product 會有大量間接存取、較難吃到向量化加速。
    private(set) var matrix: [Float] = []

    /// 建構子：把輸入的多筆向量（每筆長度 = dim）pack 成連續的 row-major 矩陣
    /// - rows: 原始資料，假設每個 `vector` 都已經 L2 normalize（若要用 cosine 分數）
    /// - dim: 向量維度 D
    init(items: [TaxonItem], dim: Int) {
        self.dim = dim
        self.ids = items.map { String($0.taxonId) }
        self.names = items.compactMap { $0.scientificName }

        // 建出 N×D 的連續 buffer，初始化為 0
        self.matrix = [Float](repeating: 0, count: items.count * dim)

        // 將每一筆向量按列（row）塞進 matrix：
        // 第 i 列的區間是 [i*dim, (i+1)*dim)
        for (i, item) in items.enumerated() {
            precondition(item.embedding.count == dim, "維度不一致")
            // 這裡使用 replaceSubrange 會將 item.embedding 的內容複製到對應區段，形成連續的 row-major 版面
            matrix.replaceSubrange(i*dim..<(i+1)*dim, with: item.embedding)
        }
    }

    /// 以 cosine（內積）計分；query 必須已 L2 normalize
    /// - 思路：把所有分數一次算完 = `scores = matrix(N×D) × query(D×1)` → 得到 `N×1`
    /// - 為什麼快：交給 Accelerate / vDSP（底層為 BLAS + SIMD + 多核心最佳化），
    ///   一次性地對連續記憶體做「矩陣×向量」計算，比逐筆 for-loop dot product 快、cache 命中率高。
    func search(query: [Float], topK: Int) -> [(id: String, name: String, score: Float)] {
        precondition(query.count == dim)
        let n = ids.count

        // scores = matrix (N×D) * query (D×1) = (N×1)
        var scores = [Float](repeating: 0, count: n)

        // vDSP_mmul 需要可變參考做為輸入指標，因此把 query 複製到 var q
        // （Array 在記憶體中本來就是連續的，這裡只是為了取得 &q 的指標）
        var q = query

        // vDSP_mmul 參數對照：
        // C = A × B
        // A: matrix (形狀 m×p) 這裡 m=n(筆數)、p=dim
        // B: q      (形狀 p×n) 這裡 n=1（單一查詢向量）
        // C: scores (形狀 m×n) -> n=1 所以是 m×1 向量
        // stride 都是 1（連續記憶體）
        // 註：`vDSP_Length` 是 UInt 型別，需轉型
        vDSP_mmul(matrix, 1, &q, 1, &scores, 1, vDSP_Length(n), 1, vDSP_Length(dim))

        // 取 Top-K：
        // - 小型資料集：直接全排序（O(N log N)）簡單明瞭
        // - 大型資料集：可改用最小堆（min-heap）或 partial sort / selection 演算法降到 O(N log K)
        let idx = (0..<n).sorted { scores[$0] > scores[$1] }.prefix(topK)
        return idx.map { (ids[$0], names[$0], scores[$0]) }
    }
}

/*
設計補充：
- Cosine 與內積：若每個向量都做 L2 normalize（‖v‖=1），cosine(v,q)=v·q，
  因此可以直接用矩陣乘法拿到 cosine 分數；若只對 query 正規化，分數會受每列向量的長度影響。
- 為什麼一次做矩陣×向量（GEMV）比逐列 dot product 快：
  1) 連續記憶體存取可大幅提高 cache 命中率
  2) vDSP/BLAS 會用 SIMD 指令（例如單指令多資料）與最佳化迴圈展開
  3) 可能利用多核心把工作拆段並行
- 後續擴展：
  - 若 N 很大且記憶體吃緊，可考慮分塊（blocking）或改為磁碟／記憶體對映（mmap）。
  - 需要更快的近似最近鄰（ANN）時，再引入 HNSW/IVF/PQ 等索引；但在 N 中小時，密集 GEMV 常常已足夠且最簡單。
*/

/*
 做什麼：
 1) 把 N 條「魚的向量」排成一個連續的大表格（N×D），攤平成一條 [Float]。
 2) 查詢時，一次做 matrix × query（矩陣×向量），得到每條魚的相似度分數。
 3) 依分數挑出前 K 名，回傳 (id, name, score)。
 為什麼這樣做比較快：
 - 連續記憶體：把資料攤平 → CPU 讀取連續、快取命中高，比 [[Float]] 這種多層陣列更有效率。
 - 一次算完：用 vDSP_mmul（底層 BLAS/SIMD/可能多核心）做 GEMV，比逐筆 for 迴圈做 dot product 快很多。
 - L2 normalize 後：cosine(v,q) == v·q（內積），所以直接用「矩陣×向量」就能拿到所有 cosine 分數。
 */
