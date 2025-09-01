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
    /// 由 CameraController 提供的影像特徵向量串流
    /// - 使用 AsyncStream<[Float]> 表示一連串的 embedding 資料
    /// - 每一筆 [Float] 就是一個 frame 的向量化結果
    @Published var embeddings: AsyncStream<[Float]>?
    /// 與 CameraPreview 綁定用的「目前活躍的相機工作階段」
    /// - 當 CameraController 建立/切換新的 AVCaptureSession 時會更新此屬性
    @Published var captureSession: AVCaptureSession?
    /// CLIP 向量萃取器是否已載入並完成預熱
    /// - View 可能依此狀態切換 UI（例如 loading / ready）
    @Published var didLoadExtractor = false
    /// 用於 .task(id:) 的觸發用識別碼
    /// - 每次重設此值即可讓消費端的 for-await 重新啟動
    @Published var streamID = UUID()
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
