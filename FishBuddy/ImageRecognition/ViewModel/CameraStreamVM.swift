//
//  CameraStreamVM.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/1.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

class CameraStreamVM: ObservableObject {
    
    @Published private(set) var database: [EmbeddingImgModel] = []
    /// 由 CameraController 提供的影像特徵向量串流
    /// - 使用 AsyncStream<[Float]> 表示一連串的 embedding 資料
    /// - 每一筆 [Float] 就是一個 frame 的向量化結果
    @Published var embeddings: AsyncStream<[Float]>?
    /// 與 CameraPreview 綁定用的「目前活躍的相機工作階段」
    /// - 當 CameraController 建立/切換新的 AVCaptureSession 時會更新此屬性
    @Published var captureSession: AVCaptureSession?
    /// 相似度最低接受門檻（cosine），依你的資料集可微調，預設 0.5
    @Published var acceptThreshold: Float = 0.5
    /// 與次高分的最小差距（動態門檻），預設 0.1；可設為 0 表示不啟用
    @Published var minGapDelta: Float = 0.1
    /// CLIP 向量萃取器是否已載入並完成預熱
    /// - View 可能依此狀態切換 UI（例如 loading / ready）
    @Published var didLoadExtractor = false
    /// 用於 .task(id:) 的觸發用識別碼
    /// - 每次重設此值即可讓消費端的 for-await 重新啟動
    @Published var streamID = UUID()
    
    /// 由 CameraController 提供的相片特徵向量串流
    @Published var imageSearchResult: [SearchResult]?
    
    func loadDatabaseIfNeeded() {
        guard database.isEmpty else { return }
        Task(priority: .utility) {
            do {
                let db = try await EmbeddingStore.shared.database()
                await MainActor.run { self.database = db }
            } catch {
                print("❌ 讀取 embedding JSON 失敗:", error)
            }
        }
    }
    
    func search(query: [Float], topK: Int = 3) {
        guard !database.isEmpty else { self.imageSearchResult = []; return }
        let scored = database.map { entry in
            (id: entry.id, score: cosineSimilarity(query, entry.vector))
        }.sorted { $0.score > $1.score }

        // 取前 K 名
        let top = Array(scored.prefix(max(1, topK)))

        // 動態門檻：需要同時通過「固定分數」與「與次高分差距」
        if let best = top.first {
            let gapOK: Bool
            if top.count >= 2 {
                let second = top[1]
                gapOK = (best.score - second.score) >= minGapDelta
            } else {
                gapOK = true
            }
            if best.score >= acceptThreshold && gapOK {
                self.imageSearchResult = top.map { SearchResult(id: $0.id, score: $0.score) }
                return
            }
        }
        self.imageSearchResult = [] // 不確定時回空陣列
    }
    
}

// @State 只能用在 View 裡面，CameraStreamVM 是 ObservableObject
// - 在 ViewModel 中使用 @Published 讓 UI 能夠偵測更新

extension CameraStreamVM {
    enum CaptureMode {
        /// 即時串流
        case stream
        /// 拍照
        case photo      
    }
}
