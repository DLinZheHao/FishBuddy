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
    /// 單例 in-memory 向量索引（從 SQLite 讀出後打包，僅建立一次）
    @Published private(set) var vectorIndex: InMemoryVectorIndex?
    /// 由 CameraController 提供的影像特徵向量串流
    /// - 使用 AsyncStream<[Float]> 表示一連串的 embedding 資料
    /// - 每一筆 [Float] 就是一個 frame 的向量化結果
    @Published var embeddings: AsyncStream<[Float32]>?
    /// 與 CameraPreview 綁定用的「目前活躍的相機工作階段」
    /// - 當 CameraController 建立/切換新的 AVCaptureSession 時會更新此屬性
    @Published var captureSession: AVCaptureSession?
    /// 相似度最低接受門檻（cosine），依你的資料集可微調，預設 0.5
    @Published var acceptThreshold: Float = 0.5
    /// 與次高分的最小差距（動態門檻），預設 0.1；可設為 0 表示不啟用
    @Published var minGapDelta: Float = 0.6
    /// CLIP 向量萃取器是否已載入並完成預熱
    /// - View 可能依此狀態切換 UI（例如 loading / ready）
    @Published var didLoadExtractor = false
    /// 用於 .task(id:) 的觸發用識別碼
    /// - 每次重設此值即可讓消費端的 for-await 重新啟動
    @Published var streamID = UUID()
    
    /// 由 CameraController 提供的相片特徵向量串流
    @Published var imageSearchResult: [SearchResult]?
    
    /// 讀取資料庫：目前是直接讀取 json 資料作為資料庫
    func loadDatabaseIfNeeded() {
        Task(priority: .utility) {
            do {
                // 依你的模型維度設定（例如 512 或 768）。這裡先用 512，你可視實際模型調整。
                let index = try await EmbeddingStore.shared.getIndex(dim: 512)
                await MainActor.run {
                    self.vectorIndex = index
                }
            } catch {
                print("❌ 建立/取得 InMemoryVectorIndex 失敗:", error)
            }
        }
    }
    
    /// 搜尋結果：目前自己計算，並產出結果
    func search(query: [Float], topK: Int = 3) {
        // 優先使用記憶體向量索引（效能最佳）。若尚未就緒，退回舊的陣列比對。
        if let index = vectorIndex {
            let results = index.search(query: query, topK: topK)
            // 門檻 + 與次高分差距規則
            if let best = results.first {
                let gapOK = results.count < 2 || (best.score - results[1].score) >= minGapDelta
                if best.score >= acceptThreshold && gapOK {
                    self.imageSearchResult = results.map { SearchResult(id: $0.id, score: $0.score) }
                    return
                }
            }
            self.imageSearchResult = []
            print("沒有符合的結果")
            return
        }
        self.imageSearchResult = []
        print("沒有符合的結果（舊邏輯）")
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
