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
    /// 緩存
    private var cache: [EmbeddingImgModel]?
    /// 資料庫
    var fishDB: FishDB?
    /// In-memory 向量索引快取（只建一次，除非資料有變動）
    private var indexCache: InMemoryVectorIndex?
    /// 當前索引的維度；避免用錯模型維度
    private var indexDim: Int = 0
    
    
    init() {
        do {
            let dbURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("fish.sqlite3")
            self.fishDB = try FishDB(path: dbURL.path)
            print("DB 路徑在:", dbURL.path)
        } catch {
            print("資料庫初始化失敗: \(error)")
        }
    }
    
    /// 把 json 的資料取出來，轉換成資料結構
    private func jsonDatabase() async throws -> [EmbeddingImgModel] {
        if let cache { return cache }
        let db = try JsonUtils.sharedInstance.loadEmbeddingJSONFromBundle(fileName: "embeddings_test_Img")
        cache = db
        return db
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
        let rows = try fishDB.loadAll()
        // 以 dim 檢查每筆維度
        guard rows.allSatisfy({ $0.vector.count == dim }) else {
            throw NSError(domain: "EmbeddingStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "向量維度不一致或與 dim 不符"]) }
        let idx = InMemoryVectorIndex(rows: rows, dim: dim)
        indexCache = idx
        indexDim = dim
        return idx
    }
    
    /// 把 json 的資料匯入 SQLite 資料庫（只需一次）
    func importFromJSONIfNeeded() async throws {
        let imported = UserDefaults.standard.bool(forKey: "didImportEmbeddings")
        
        /// 讀取 JSON 檔，讓 EmbeddingStore  cache 有已經處理好的資料
        let entries = try await jsonDatabase()
        guard !imported else { return }
        
        for e in entries {
            try fishDB?.upsert(row: EmbeddingImgModel(id: e.id, name: e.name, vector: e.vector))
        }
        
        // 匯入完畢後預先建立索引（忽略錯誤；之後 getIndex 會再嘗試）
        Task { [weak self] in
            try? await self?.getIndex(dim: entries.first?.vector.count ?? 512)
        }
        
        UserDefaults.standard.set(true, forKey: "didImportEmbeddings")
    }
}

final class FishDB {
    /// 資料庫
    private let db: Connection
    /// 資料表
    private let fish = Table("fish")
    /// 欄位: id, name, vector, meta
    private let colId = SQLite.Expression<String>("id")
    private let colName = SQLite.Expression<String>("name")
    private let colVector = SQLite.Expression<SQLite.Blob>("vector")
    private let colMeta = SQLite.Expression<String?>("meta")

    init(path: String) throws {
        db = try Connection(path)
        try db.run(fish.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colName)
            t.column(colVector)
            t.column(colMeta)
        })
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

    // 新增或更新一筆資料
    func upsert(row: EmbeddingImgModel, meta: String? = nil) throws {
        let blob = floatsToBlob(row.vector)
        let insert = fish.insert(or: .replace, // 覆蓋原先的資料
                                 colId <- row.id,
                                 colName <- row.name,
                                 colVector <- blob,
                                 colMeta <- meta)
        try db.run(insert)
    }

    // 讀取所有資料
    func loadAll() throws -> [EmbeddingImgModel] {
        try db.prepare(fish.select(colId, colName, colVector)).map { r in
            EmbeddingImgModel(id: r[colId], name: r[colName], vector: blobToFloats(r[colVector]))
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
    init(rows: [EmbeddingImgModel], dim: Int) {
        self.dim = dim
        self.ids = rows.map { $0.id }
        self.names = rows.map { $0.name }

        // 建出 N×D 的連續 buffer，初始化為 0
        self.matrix = [Float](repeating: 0, count: rows.count * dim)

        // 將每一筆向量按列（row）塞進 matrix：
        // 第 i 列的區間是 [i*dim, (i+1)*dim)
        for (i, r) in rows.enumerated() {
            precondition(r.vector.count == dim, "維度不一致")
            // 這裡使用 replaceSubrange 會將 r.vector 的內容複製到對應區段，形成連續的 row-major 版面
            matrix.replaceSubrange(i*dim..<(i+1)*dim, with: r.vector)
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
