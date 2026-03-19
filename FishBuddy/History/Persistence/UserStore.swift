//
//  UserStore.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/2/24.
//

import Foundation
import SQLite

actor UserStore {
    static let shared = UserStore()
    
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
    
    func prepare() {
        // 防止重複初始化
        if db != nil { return }
        do {
            let url = try userDBURL()
            db = try Connection(url.path)
            
            // 可選：基本 pragma
            try db?.run("PRAGMA foreign_keys = ON;")
            
            try ensureSchema()
            print("✅ User DB 路徑:", url.path)
        } catch {
            fatalError("❌ UserStore prepare failed: \(error)")
        }
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
        guard let db else { throw NSError(domain: "UserStore", code: 1) }
        
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
        guard let db else { throw NSError(domain: "UserStore", code: 2) }
        try db.run(favorites.insert(or: .replace,
                                    taxonId <- taxonID,
                                    createdAt <- now))
    }
    
    /// 取消收藏
    func removeFavorite(taxonID: Int) throws {
        guard let db else { throw NSError(domain: "UserStore", code: 2) }
        try db.run(favorites.filter(taxonId == taxonID).delete())
    }
    
    /// 是否已收藏
    func isFavorite(taxonID: Int) throws -> Bool {
        guard let db else { throw NSError(domain: "UserStore", code: 2) }
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
        guard let db else { throw NSError(domain: "UserStore", code: 2) }
        var result: [Int] = []
        for row in try db.prepare(favorites.order(createdAt.desc).limit(limit)) {
            result.append(row[taxonId])
        }
        return result
    }
    
    
    // MARK: - History (v1)
    
    /// 建立一次辨識 session；可選擇存一張代表縮圖（長邊 <= 1024）
    /// - Returns: session id
    func createSession(sourceValue: String = "camera",
                       thumbnailJPEGData: Data? = nil,
                       now: Int64 = Int64(Date().timeIntervalSince1970)) throws -> Int64 {
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        
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
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        
        let sql = "INSERT INTO taxon_view_history (created_at, taxon_id, session_id, entry) VALUES (?, ?, ?, ?)"
        let stmt = try db.prepare(sql)
        try stmt.run(now, taxonID, sessionID, entryValue)
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
        ranked: [(taxonId: Int, score: Float)],
        now: Int64 = Int64(Date().timeIntervalSince1970),
        replaceExisting: Bool = true
    ) throws {
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        
        try db.transaction {
            if replaceExisting {
                let del = try db.prepare("DELETE FROM recognition_result WHERE session_id = ?")
                try del.run(sessionID)
            }
            
            guard !ranked.isEmpty else { return }
            
            let insertSQL = "INSERT INTO recognition_result (session_id, taxon_id, score, rank, created_at) VALUES (?, ?, ?, ?, ?)"
            let stmt = try db.prepare(insertSQL)
            for (idx, item) in ranked.enumerated() {
                try stmt.run(sessionID, item.taxonId, Double(item.score), idx + 1, now)
            }
        }
    }
    
    struct TaxonViewRow: Sendable {
        let taxonID: Int
        let createdAt: Int64
        let sessionID: Int64?
    }
    
    /// 取得最近瀏覽紀錄（新到舊）
    func fetchRecentViews(limit: Int = 200) throws -> [TaxonViewRow] {
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        var result: [TaxonViewRow] = []
        
        // 用 raw SQL 直接撈，避免 optional column 在不同 SQLite.swift 版本的差異
        let sql = "SELECT taxon_id, created_at, session_id FROM taxon_view_history ORDER BY created_at DESC LIMIT ?"
        let stmt = try db.prepare(sql)
        for row in try stmt.run(limit) {
            let taxon = row[0] as! Int64
            let created = row[1] as! Int64
            let session = row[2] as? Int64
            result.append(.init(taxonID: Int(taxon), createdAt: created, sessionID: session))
        }
        return result
    }
    
    /// 由 session id 取得縮圖路徑（若有）
    func fetchSessionImagePath(sessionID: Int64) throws -> String? {
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        let sql = "SELECT image_path FROM recognition_session WHERE id = ? LIMIT 1"
        let stmt = try db.prepare(sql)
        for row in try stmt.run(sessionID) {
            return row[0] as? String
        }
        return nil
    }
    
    // MARK: - Maintenance & Cleanup
    
    /// 刪除一筆辨識 session：
    /// - 會先把 taxon_view_history 內引用該 session 的紀錄設為 NULL（保留瀏覽歷史）。
    /// - 會刪除 recognition_session 的資料列（recognition_result 會因外鍵 CASCADE 一併刪除）。
    /// - 會嘗試刪除該 session 的縮圖檔（若存在）。
    func deleteSession(sessionID: Int64) throws {
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        
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
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        
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
        guard let db else { throw NSError(domain: "UserStore", code: 3) }
        
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
    
    /// Save thumbnail JPEG into Application Support/FishBuddy/images/ with a UUID filename.
    /// NOTE: We assume the input data is already JPEG-encoded and already resized to max side <= 1024.
    private func saveThumbnailJPEG(_ jpegData: Data) throws -> String {
        let dir = try thumbnailsDirURL()
        let name = UUID().uuidString + ".jpg"
        let url = dir.appendingPathComponent(name)
        try jpegData.write(to: url, options: [.atomic])
        return url.path
    }
}
