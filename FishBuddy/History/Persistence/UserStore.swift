//
//  UserStore.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/2/24.
//

import Foundation
import SQLite
import UIKit

actor UserStore {
    static let shared = UserStore()
    private let notPreparedError = NSError(domain: "UserStore", code: 1)
    
    private var db: Connection?
    private let fileName = "user.sqlite"
    
    // Tables
    private let sessions = Table("recognition_session")
    private let views = Table("taxon_view_history")
    private let favorites = Table("favorites")
    
    // Columns
    private let id = Expression<Int64>("id")
    private let createdAt = Expression<Int64>("created_at")
    private let taxonId = Expression<Int>("taxon_id")
    private let sessionId = Expression<Int64?>("session_id")
    private let imagePath = Expression<String?>("image_path")
    private let source = Expression<String>("source") // Session input source, e.g. "camera", "library"
    private let entry  = Expression<String>("entry")  // Where the taxon detail was opened from ..., e.g. "identify", "favorites", "history"
    
    private init() {}
    
    func prepare() throws {
        // 防止重複初始化
        if db != nil { return }
        
        let url = try userDBURL()
        db = try Connection(url.path)
        
        // 可選：基本 pragma
        try db?.run("PRAGMA foreign_keys = ON;")
        
        try ensureSchema()
        print("✅ User DB 路徑:", url.path)
    }
    
    private func preparedDB() throws -> Connection {
        try prepare()
        guard let db else { throw notPreparedError }
        return db
    }
    
    private func userDBURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        
        let dir = appSupport.appendingPathComponent("FishBuddy", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }
    
    private func ensureSchema() throws {
        guard let db else { throw notPreparedError }
        
        // recognition_session (one recognition attempt; may have a saved thumbnail)
        try db.run(sessions.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(createdAt)
            t.column(imagePath)
            t.column(source)
        })
        try db.run("CREATE INDEX IF NOT EXISTS idx_session_created_at ON recognition_session(created_at);")
        
        // taxon_view_history (user actually entered a taxon detail page)
        try db.run("""
        CREATE TABLE IF NOT EXISTS taxon_view_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER,
            taxon_id INTEGER,
            session_id INTEGER,
            entry TEXT,
            FOREIGN KEY(session_id) REFERENCES recognition_session(id) ON DELETE SET NULL
        );
        """)
        try db.run("CREATE INDEX IF NOT EXISTS idx_view_created_at ON taxon_view_history(created_at);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_view_taxon_id ON taxon_view_history(taxon_id);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_view_session_id ON taxon_view_history(session_id);")
        
        // favorites
        try db.run(favorites.create(ifNotExists: true) { t in
            t.column(taxonId, primaryKey: true)
            t.column(createdAt)
        })
        try db.run("CREATE INDEX IF NOT EXISTS idx_favorites_created_at ON favorites(created_at);")
        
        // recognition_result (model candidates per session)
        try db.run("""
        CREATE TABLE IF NOT EXISTS recognition_result (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            taxon_id INTEGER NOT NULL,
            score REAL NOT NULL,
            rank INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(session_id) REFERENCES recognition_session(id) ON DELETE CASCADE
        );
        """)
        try db.run("CREATE INDEX IF NOT EXISTS idx_result_session_id ON recognition_result(session_id);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_result_taxon_id ON recognition_result(taxon_id);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_result_created_at ON recognition_result(created_at);")
    }
    
    // MARK: - Favorites
    
    /// 收藏（若已收藏則更新 created_at）
    func addFavorite(taxonID: Int, now: Int64 = Int64(Date().timeIntervalSince1970)) throws {
        let db = try preparedDB()
        try db.run(favorites.insert(or: .replace,
                                    taxonId <- taxonID,
                                    createdAt <- now))
    }
    
    /// 取消收藏
    func removeFavorite(taxonID: Int) throws {
        let db = try preparedDB()
        try db.run(favorites.filter(taxonId == taxonID).delete())
    }
    
    /// 是否已收藏
    func isFavorite(taxonID: Int) throws -> Bool {
        let db = try preparedDB()
        print("檢查是否收藏")
        // scalar(count) 會回傳 Int
        let count = try db.scalar(favorites.filter(taxonId == taxonID).count) // SELECT COUNT(*) FROM favorites WHERE taxonId = ?
        return count > 0
    }
    
    /// 切換收藏狀態；回傳切換後是否為「已收藏」
    @discardableResult
    func toggleFavorite(taxonID: Int, now: Int64 = Int64(Date().timeIntervalSince1970)) throws -> Bool {
        if try isFavorite(taxonID: taxonID) {
            try removeFavorite(taxonID: taxonID)
            return false
        } else {
            try addFavorite(taxonID: taxonID, now: now)
            return true
        }
    }
    
    /// 取得收藏清單（依 created_at 由新到舊）
    func fetchFavoriteTaxonIDs(limit: Int = 500) throws -> [Int] {
        let db = try preparedDB()
        var result: [Int] = []
        for row in try db.prepare(favorites.order(createdAt.desc).limit(limit)) {
            result.append(row[taxonId])
        }
        return result
    }
    
    
    // MARK: - History (v1)
    
    /// 建立一次辨識 session；可選擇存一張代表縮圖（長邊 <= 1024）
    /// - Returns: session id
    @discardableResult
    func createSession(sourceValue: String = "camera",
                       thumbnailJPEGData: Data? = nil,
                       now: Int64 = Int64(Date().timeIntervalSince1970)) throws -> Int64 {
        let db = try preparedDB()
        
        let savedPath: String?
        if let data = thumbnailJPEGData {
            savedPath = try saveThumbnailJPEG(data)
        } else {
            savedPath = nil
        }
        
        let rowid = try db.run(sessions.insert(
            createdAt <- now,
            imagePath <- savedPath,
            source <- sourceValue
        ))
        return rowid
    }
    
    /// 記錄使用者實際進入的物種頁（不是 top1；是 user click）
    func logTaxonView(taxonID: Int,
                      entryValue: String = "identify",
                      sessionID: Int64? = nil,
                      now: Int64 = Int64(Date().timeIntervalSince1970)) throws {
        let db = try preparedDB()
        
        let sql = "INSERT INTO taxon_view_history (created_at, taxon_id, session_id, entry) VALUES (?, ?, ?, ?)"
        let stmt = try db.prepare(sql)
        try stmt.run(now, taxonID, sessionID, entryValue)
    }
    
    /// 由 session id 取得縮圖路徑（若有）
    func fetchSessionImagePath(sessionID: Int64) throws -> String? {
        let db = try preparedDB()
        let sql = "SELECT image_path FROM recognition_session WHERE id = ? LIMIT 1"
        let stmt = try db.prepare(sql)
        for row in try stmt.run(sessionID) {
            return row[0] as? String
        }
        return nil
    }

    /// 由 session id 直接取得 UIImage（若有）
    /// - Parameter sessionID: recognition_session.id
    /// - Returns: 對應的 UIImage，若路徑不存在或讀取失敗則回傳 nil
    func fetchSessionImage(sessionID: Int64) throws -> UIImage? {
        guard let storedName = try fetchSessionImagePath(sessionID: sessionID) else {
            print("圖片獲取失敗：找不到相應的路徑")
            return nil
        }

        let path = try resolveThumbnailPath(from: storedName)
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: path)
        print("stored image name: \(storedName)")
        print("resolved path: \(path)")
        print("file exists: \(exists)")

        guard exists else {
            print("圖片檔案不存在")
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            print("image data size: \(data.count)")

            let image = UIImage(data: data)
            print("UIImage(data:) success: \(image != nil)")
            return image
        } catch {
            print("讀取圖片 data 失敗: \(error)")
            return nil
        }
    }

    /// 由 taxon id 取得物種照片（若有）
    /// - Parameter taxonID: species.taxon_id
    /// - Returns: 對應的 UIImage，若無 photos 資料或下載失敗則回傳 nil
    func fetchTaxonViewImage(taxonID: Int) async throws -> UIImage? {
        guard let fishDB = await EmbeddingStore.shared.fishDB else {
            print("FishDB 尚未初始化")
            return nil
        }

        let items = try fishDB.loadTaxonItems(taxonIds: [taxonID])
        guard let urlString = items.first?.photos.first?.url,
              let url = URL(string: urlString) else {
            print("找不到 taxon \(taxonID) 對應的 photos 資料")
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("下載 taxon \(taxonID) 圖片失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - Recognition Sessions Query
    
    /// 取得最近的辨識 Session，並包含其對應的候選結果（依 rank 排序）。
    /// - Parameters:
    ///   - limit: 最多回傳幾筆 session（依 created_at 由新到舊排序），預設 50。
    /// - Returns: 包含 session 基本資訊與候選結果的完整資料結構陣列。
    /// - Note:
    ///   - 目前採用 N+1 Query（每個 session 各查一次結果），實作簡單且可讀性高。
    ///   - 若未來資料量增加，可優化為 JOIN + grouping 以減少查詢次數。
    func fetchRecognitionSessions(limit: Int = 50) throws -> [RecognitionSessionDetail] {
        print("進入資料庫查詢（前）")
        let db = try preparedDB()
        print("進入資料庫查詢（後）")
        var sessionsResult: [RecognitionSessionDetail] = []
        
        // 1️⃣ 先撈 session
        let sessionSQL = """
        SELECT id, created_at, image_path, source
        FROM recognition_session
        ORDER BY created_at DESC
        LIMIT ?
        """
        
        let sessionStmt = try db.prepare(sessionSQL)
        
        for row in try sessionStmt.run(limit) {
            let sessionID = row[0] as! Int64
            let createdAt = row[1] as! Int64
            let imagePath = row[2] as? String
            let source = row[3] as! String
            
            // 2️⃣ 撈對應 candidates
            let resultSQL = """
            SELECT taxon_id, score, rank
            FROM recognition_result
            WHERE session_id = ?
            ORDER BY rank ASC
            """
            
            let resultStmt = try db.prepare(resultSQL)
            
            var candidates: [RecognitionCandidate] = []
            for r in try resultStmt.run(sessionID) {
                candidates.append(
                    RecognitionCandidate(
                        taxonID: Int(r[0] as! Int64),
                        score: r[1] as! Double,
                        rank: r[2] as! Int64
                    )
                )
            }
            
            sessionsResult.append(
                RecognitionSessionDetail(
                    sessionID: sessionID,
                    createdAt: createdAt,
                    imagePath: imagePath,
                    source: source,
                    results: candidates
                )
            )
        }
        
        return sessionsResult
    }
    
    // MARK: - Recognition results logging
    /// 紀錄一次辨識的候選清單（top-K）。
    /// - Parameters:
    ///   - sessionID: 對應 recognition_session.id
    ///   - ranked: 依排序傳入 (taxonId, score)，index 由 0 起算會自動轉成 rank=1,2,3...
    ///   - now: Unix 秒級時間戳
    ///   - replaceExisting: 若該 session 先前已有紀錄，是否先清空再寫入（預設 true）
    func logRecognitionResults(
        sessionID: Int64,
        ranked: [(taxon: TaxonItem, score: Float)],
        now: Int64 = Int64(Date().timeIntervalSince1970),
        replaceExisting: Bool = true
    ) throws {
        let db = try preparedDB()
        
        try db.transaction {
            if replaceExisting {
                let del = try db.prepare("DELETE FROM recognition_result WHERE session_id = ?")
                try del.run(sessionID)
            }
            
            guard !ranked.isEmpty else { return }
            
            let insertSQL = "INSERT INTO recognition_result (session_id, taxon_id, score, rank, created_at) VALUES (?, ?, ?, ?, ?)"
            let stmt = try db.prepare(insertSQL)
            for (idx, item) in ranked.enumerated() {
                try stmt.run(sessionID, item.taxon.taxonId, Double(item.score), idx + 1, now)
            }
            print("RecognitionResults save successfully.")
        }
    }
    
    /// 取得最近瀏覽紀錄（新到舊）
    func fetchTaxonViewHistory(limit: Int = 200) throws -> [TaxonViewHistoryDetail] {
        let db = try preparedDB()
        var result: [TaxonViewHistoryDetail] = []
        
        let sql = """
        SELECT id, taxon_id, created_at, session_id, entry
        FROM taxon_view_history
        ORDER BY created_at DESC
        LIMIT ?
        """
        let stmt = try db.prepare(sql)
        for row in try stmt.run(limit) {
            let id = row[0] as! Int64
            let taxon = row[1] as! Int64
            let created = row[2] as! Int64
            let session = row[3] as? Int64
            let entry = row[4] as? String ?? ""
            result.append(
                TaxonViewHistoryDetail(
                    id: id,
                    createdAt: created,
                    taxonID: Int(taxon),
                    sessionID: session,
                    entry: entry
                )
            )
        }
        return result
    }
    
    // MARK: - Maintenance & Cleanup
    
    /// 刪除一筆辨識 session：
    /// - 會先把 taxon_view_history 內引用該 session 的紀錄設為 NULL（保留瀏覽歷史）。
    /// - 會刪除 recognition_session 的資料列（recognition_result 會因外鍵 CASCADE 一併刪除）。
    /// - 會嘗試刪除該 session 的縮圖檔（若存在）。
    func deleteSession(sessionID: Int64) throws {
        let db = try preparedDB()
        
        var pathToDelete: String?
        try db.transaction {
            // 先查出縮圖路徑
            let sel = try db.prepare("SELECT image_path FROM recognition_session WHERE id = ? LIMIT 1")
            for row in try sel.run(sessionID) {
                pathToDelete = row[0] as? String
            }
            // 刪除 session（recognition_result 會因外鍵自動刪除）
            let del = try db.prepare("DELETE FROM recognition_session WHERE id = ?")
            try del.run(sessionID)
        }
        
        // 交易完成後再刪縮圖檔，避免 DB 失敗卻刪了檔案
        if let p = pathToDelete {
            let fm = FileManager.default
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }
    
    /// 刪除早於指定時間戳的所有 session（Unix 秒）。
    /// - 會清空 taxon_view_history 對這些 session 的引用（設為 NULL），並刪除 session 本身與其候選。
    /// - 回傳刪除的 session 數量。
    @discardableResult
    func purgeSessions(olderThan cutoff: Int64) throws -> Int {
        let db = try preparedDB()
        
        var ids: [Int64] = []
        var paths: [String] = []
        
        try db.transaction {
            // 先抓出要刪除的 id 與縮圖路徑
            let sel = try db.prepare("SELECT id, image_path FROM recognition_session WHERE created_at < ?")
            for row in try sel.run(cutoff) {
                let sid = row[0] as! Int64
                ids.append(sid)
                if let p = row[1] as? String { paths.append(p) }
            }
            
            guard !ids.isEmpty else { return }
            
            // 刪除符合條件的 sessions（recognition_result 會自動跟著刪除）
            let del = try db.prepare("DELETE FROM recognition_session WHERE created_at < ?")
            try del.run(cutoff)
        }
        
        // 交易完成後再刪縮圖檔
        let fm = FileManager.default
        for p in paths {
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
        return ids.count
    }
    
    /// 便利方法：刪除早於指定天數的所有 session。
    @discardableResult
    func purgeSessions(olderThanDays days: Int) throws -> Int {
        let now = Int64(Date().timeIntervalSince1970)
        let cutoff = now - Int64(days) * 86_400
        return try purgeSessions(olderThan: cutoff)
    }
    
    /// 清理 images/ 目錄下所有「資料庫未引用」的縮圖檔。
    /// - Returns: 刪除的檔案數量
    @discardableResult
    func cleanupOrphanThumbnails() throws -> Int {
        let db = try preparedDB()
        
        // 讀取目前 DB 中仍被引用的縮圖路徑
        var referenced: Set<String> = []
        let sel = try db.prepare("SELECT image_path FROM recognition_session WHERE image_path IS NOT NULL")
        for row in try sel.run() {
            if let p = row[0] as? String { referenced.insert(p) }
        }
        
        let dir = try thumbnailsDirURL()
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        
        var removed = 0
        for url in files {
            let path = url.path
            if !referenced.contains(path) {
                do {
                    try fm.removeItem(at: url)
                    removed += 1
                } catch {
                    // 個別刪除失敗不影響整體流程
                }
            }
        }
        return removed
    }
    
    private func resolveThumbnailPath(from storedName: String) throws -> String {
        let dir = try thumbnailsDirURL()
        return dir.appendingPathComponent(storedName).path
    }

    // MARK: - Thumbnail storage
    
    private func thumbnailsDirURL() throws -> URL {
        let base = try userDBURL().deletingLastPathComponent()
        let dir = base.appendingPathComponent("images", isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Save thumbnail JPEG into Application Support/FishBuddy/images/ with a UUID filename and return the stored filename.
    /// NOTE: We assume the input data is already JPEG-encoded and already resized to max side <= 1024.
    private func saveThumbnailJPEG(_ jpegData: Data) throws -> String {
        let dir = try thumbnailsDirURL()
        let name = UUID().uuidString + ".jpg"
        let url = dir.appendingPathComponent(name)
        try jpegData.write(to: url, options: [.atomic])
        return name
    }
}
