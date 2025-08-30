//
//  ImageRecognitionView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/8/28.
//

import SwiftUI
import AVFoundation
import CoreML

struct CameraStreamView: View {
    @StateObject private var camera = CameraController()
    @State private var embeddings: AsyncStream<[Float]>?
    @State private var captureSession: AVCaptureSession?
    @State private var didLoadExtractor = false
    @State private var streamID = UUID()
    
    var body: some View {
        VStack {
            // 穩定掛載 Preview；session 之後可遲到更新
            ZStack {
                CameraPreview(session: captureSession)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.4), lineWidth: 1))

                if camera.captureSession == nil {
                    // 首次啟動尚未有 session 時顯示 loading
                    ProgressView("啟動相機中…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            // 當換成「新的」 AVCaptureSession 實例時，強制 SwiftUI 重新建構預覽
            .id(camera.captureSession.map { ObjectIdentifier($0) })
            .padding(.horizontal)
            // 切換前/後鏡頭
            Toggle("後鏡頭", isOn: Binding(
                get: { camera.backCamera },
                set: { camera.backCamera = $0 }
            ))
            .padding()

            // 用 Task 讀取 embedding（此處只示範取到就計數/處理）
            if let embeddings {
                EmbeddingConsumer(stream: embeddings, id: streamID)
            } else {
                Text("尚未啟動相機")
            }
        }
        .onAppear {
            // 每次回到此頁都重新建立一條新的 embeddings stream，
            // 讓消費端的 for-await 能可靠重啟；Camera 本身不會重開。
            let stream = AsyncStream<[Float]> { continuation in
                camera.attachEmbedding(continuation: continuation)
                // 僅在尚未啟動時才會真正啟動相機
                camera.startIfNeeded()
            }
            self.embeddings = stream
            self.streamID = UUID()

            // 只在第一次載入時建立與預熱 CLIP 模型
            if !didLoadExtractor {
                Task.detached(priority: .userInitiated) {
                    let extractor = CLIPFeatureExtractor()
                    // 預熱：讓第一次推論不卡
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 224, height: 224))
                    let warmup = renderer.image { _ in
                        UIColor.black.setFill()
                        UIBezierPath(rect: CGRect(x: 0, y: 0, width: 224, height: 224)).fill()
                    }
                    _ = extractor.embedding(for: warmup)
                    await MainActor.run {
                        camera.clipExtractor = extractor
                        didLoadExtractor = true
                    }
                }
            }

            camera.onSessionReady = { session in
                captureSession = session
            }
        }
        .onDisappear {
            // 在 Tab 切換時不要停止相機與釋放資源，避免重建成本
            // 若需要在真正離開功能頁時釋放，請在上層做集中管理再呼叫 stop/detatch。
        }
    }
}

// MARK: - UIKit bridge for live camera preview (best for low-latency display)
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView(frame: .zero)
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // 若後來才取得 session，或換了新的 session，都在此更新
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }
}

// 僅傳遞 [Float]，避免 CMSampleBuffer 的 Sendable 問題
struct EmbeddingConsumer: View {
    let stream: AsyncStream<[Float]>
    let id: UUID

    var body: some View {
        Text("攝影機已啟動")
            .task(id: id) {
                var idx = 0
                for await vec in stream {
                    idx += 1
                    print("[UI] got embedding #\(idx), dim=\(vec.count)")
                }
            }
    }
}
