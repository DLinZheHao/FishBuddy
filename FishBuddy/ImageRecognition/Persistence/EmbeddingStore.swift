//
//  EmbeddingStore.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/12/21.
//

import SQLite
import Foundation

/// 快捷的取得 Embedding 資料：使用 json
actor EmbeddingStore {
    /// 共用實例
    static let shared = EmbeddingStore()
    /// 資料庫
    var fishDB: FishDB?
    /// In-memory 向量索引快取（只建一次，除非資料有變動）
    private var indexCache: InMemoryVectorIndex?
    /// 相似度最低接受門檻（cosine），依你的資料集可微調，預設 0.5
    var acceptThreshold: Float = 0.5
    /// 與次高分的最小差距（動態門檻），預設 0.1；可設為 0 表示不啟用
    var minGapDelta: Float = 0.1
    /// 當前索引的維度；避免用錯模型維度
    private var indexDim: Int = 0
    
    init() {
        // init 內避免做重 IO / 可能失敗的工作（copy/open DB），讓生命週期更可控
        // 請在 App 啟動時呼叫：`Task { await EmbeddingStore.shared.prepare() }`
    }

    /// 準備資料庫（第一次啟動會從 bundle 複製到可寫位置），並初始化 FishDB
    func prepare() async {
        do {
            let dest = try Self.defaultDBURL()
            try Self.ensureDatabaseCopiedIfNeeded(to: dest)
            self.fishDB = try FishDB(path: dest.path)
            print("✅ DB 路徑在:", dest.path)
        } catch {
            print("❌ 資料庫初始化失敗:", error)
        }
    }

    /// 讀取 application support 中理論上的 sqlite file 資料路徑
    private static func defaultDBURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true)
        let dir = appSupport.appendingPathComponent("FishBuddy", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("catalog.sqlite")
    }

    /// 第一次啟動：若 Application Support 裡沒有 DB，嘗試從 bundle 複製預載檔
    /// - 如果已經存在檔案則會直接返回
    /// - 用 replaceItemAt 走「先寫 temp 再原子替換」，避免 copy 中斷留下半套檔
    private static func ensureDatabaseCopiedIfNeeded(to dest: URL) throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: dest.path) else { return }

        guard let src = Bundle.main.url(forResource: "catalog", withExtension: "sqlite") else {
            print("⚠️ bundle 內找不到 catalog.sqlite，將在首次啟動時以 DDL 建立空 schema。")
            return
        }

        // 原子寫入：先 copy 到 temp，再 replace
        let tmp = dest.deletingLastPathComponent().appendingPathComponent("catalog.tmp.sqlite")
        if fm.fileExists(atPath: tmp.path) {
            try? fm.removeItem(at: tmp)
        }
        // The copyItem operation involves writing, so it must complete fully to avoid corruption.
        try fm.copyItem(at: src, to: tmp)
        // The replace operation must complete fully; otherwise, it will not be executed.
        _ = try fm.replaceItemAt(dest, withItemAt: tmp, backupItemName: nil, options: .usingNewMetadataOnly)
        print("✅ 已從 bundle 複製 DB 至:", dest.path)
    }
    
    /// 取得（或建立）InMemoryVectorIndex：會從 SQLite 載入全部向量，打包成 N×D 矩陣，只做一次
    /// - Parameter dim: 向量維度（例如 512 或 768）
    /// - Returns: 可重用的 InMemoryVectorIndex 實例
    func buildIndexIfNeeded(dim: Int) async throws {
        if let idx = indexCache, indexDim == dim {
            return
        }
        guard let fishDB
        else {
            throw NSError(domain: "EmbeddingStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "FishDB 未初始化"])
        }
        
        // 從 SQLite 讀取全部 embedding（以 taxon_id 分組）
        let embeddingsByTaxonId = try fishDB.loadAllEmbeddings()

        // 以 dim 檢查每筆向量維度（任一不符就直接丟錯，避免用錯模型或資料被污染）
        for (taxonId, list) in embeddingsByTaxonId {
            for e in list {
                guard e.vector.count == dim else {
                    throw NSError(
                        domain: "EmbeddingStore",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "向量維度不一致：taxon_id=\(taxonId) idx=\(e.idx) expected=\(dim) actual=\(e.vector.count)"]
                    )
                }
            }
        }

        // 建立（或重建）in-memory index：只保留 (taxonId, photoIdx) key + packed matrix，用於快速計算
        let idx = InMemoryVectorIndex(embeddingsByTaxonId: embeddingsByTaxonId, dim: dim)
        indexCache = idx
        indexDim = dim
    }
    
    /// Search top-K embeddings.
    /// - Returns: `(taxonId, photoIdx, score)` where score is mapped to 0~100.
    func search(query: [Float], topK: Int) async -> [(TaxonItem, Float)] {
        guard let idx = indexCache, let fishDB else { return [] }
        let results: [(key: InMemoryVectorIndex.EmbeddingKey, score: Float)] = idx.search(query: query, topK: topK)
        guard !results.isEmpty else { return [] }

        // 1) 同一個 taxonId 可能多筆（不同 photoIdx）
        //    我們只保留該 taxonId 的「最高分」
        var bestScoreByTaxon: [Int: Float] = [:]
        for r in results {
            let tid = r.key.taxonId
            let s = r.score
            if let cur = bestScoreByTaxon[tid] {
                if s > cur { bestScoreByTaxon[tid] = s }
            } else {
                bestScoreByTaxon[tid] = s
            }
        }

        // 1.5) 先用 acceptThreshold 過濾掉太低的分數，避免後續多餘的 DB 查詢
        // idx.search 的分數通常是 cosine similarity（0~1），acceptThreshold 也以同尺度設定。
        if acceptThreshold > 0 {
            bestScoreByTaxon = bestScoreByTaxon.filter { $0.value >= acceptThreshold }
        }
        guard !bestScoreByTaxon.isEmpty else { return [] }

        // 2) 依分數排序，得到 taxonIds（這就是你要回傳的排序）
        let sortedTaxonIds = bestScoreByTaxon
            .sorted { $0.value > $1.value }
            .map { $0.key }

        // 3) 一次去 DB 撈出 TaxonItem（你已經寫好了）
        var items: [TaxonItem] = []
        do {
            items = try fishDB.loadTaxonItems(taxonIds: sortedTaxonIds)
        } catch {
            fatalError("DB 載入失敗 \(error)")
        }
        
        // 4) 建 dictionary 方便配對
        let itemById: [Int: TaxonItem] = Dictionary(uniqueKeysWithValues: items.map { ($0.taxonId, $0) })

        // 5) 回傳「TaxonItem + score」且一定對得上
        let final: [(item: TaxonItem, score: Float)] = sortedTaxonIds.compactMap { tid in
            guard let item = itemById[tid], let score = bestScoreByTaxon[tid] else { return nil }
            return (item: item, score: score)
        }

        return final
    }
}
