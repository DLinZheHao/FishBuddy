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
    /// 讀取的 taxonItem 暫存
    var taxonItemCache: [TaxonItem] = []
    /// In-memory 向量索引快取（只建一次，除非資料有變動）
    private var indexCache: InMemoryVectorIndex?
    /// 相似度最低接受門檻（cosine），依你的資料集可微調，預設 0.5
    var acceptThreshold: Float = 0.6
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
    func getIndex(dim: Int) async throws {
        if let idx = indexCache, indexDim == dim {
            return
        }
        guard let fishDB
        else {
            throw NSError(domain: "EmbeddingStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "FishDB 未初始化"])
        }
        
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
    }
    
    func searchWithItems(query: [Float], topK: Int) async throws -> [(TaxonItem, Float)] {
        if let idx = indexCache {
            let results = idx.search(query: query, topK: topK)
            
            // 門檻 + 與次高分差距規則
            if let best = results.first {
                let gapOK = results.count < 2 || (best.score - results[1].score) >= minGapDelta
                if best.score >= (acceptThreshold * 100) && gapOK {
                    return results.compactMap { r in
                        if let item = taxonItemCache.first(where: { String($0.taxonId) == r.id }) {
                            return (item, r.score)
                        }
                        return nil
                    }
                }
            }
            
        }
        return []
    }
}
