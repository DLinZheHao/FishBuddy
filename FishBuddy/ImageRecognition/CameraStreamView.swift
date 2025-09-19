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
    /// 相機鏡頭物件
    @StateObject private var camera = CameraController()
    /// ViewModel
    @ObservedObject private var vm = CameraStreamVM()
    /// 最後一次拍攝照片
    @State private var lastPhoto: UIImage?
    /// 測試切割後的照片結果
    @State private var resultImage: UIImage?
    /// 拍攝運作模式
    typealias CaptureMode = CameraStreamVM.CaptureMode
    
    var body: some View {
        ZStack {
            // Full-screen camera preview (edge-to-edge)
            ZStack {
                CameraPreview(session: vm.captureSession)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                if camera.captureSession == nil {
                    // 首次啟動尚未有 session 時顯示 loading
                    ProgressView("啟動相機中…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            // 當換成「新的」AVCaptureSession 實例時，強制 SwiftUI 重新建構預覽（每次切換都會開啟新的 session）
            .id(camera.captureSession.map { ObjectIdentifier($0) }) // ObjectIdentifier 是一種「以物件記憶體身份作為唯一值」的東西

            // Overlay UI
            VStack {
                HStack {
                    Spacer()
                    // 切換前/後鏡頭
                    Toggle("後鏡頭", isOn: Binding(
                        get: { camera.backCamera },
                        set: { camera.backCamera = $0 }
                    ))
                    .labelsHidden()
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 12)
                .padding(.horizontal, 16)

                Spacer()

                // 搜尋結果顯示（上方左側浮出）
                if let results = vm.imageSearchResult, !results.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📷 搜尋結果")
                            .font(.headline)
                            .padding(.bottom, 4)

                        ForEach(Array(results.prefix(3)), id: \.0.taxonId) { (item, score) in
                            HStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.blue.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(item.taxonId))
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    )

                                VStack(alignment: .leading) {
                                    Text("ID: \(item.taxonId)")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(String(format: "相似度: %.2f", score))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.1)))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
                
                if let resultImage {
                    Image(uiImage: resultImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            
            
        }
        // 在 safeArea 撰寫工具
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                if let _ = lastPhoto {
                    Color.clear
                        .frame(width: 56, height: 56)
                }
                Spacer()

                Button {
                    camera.capturePhoto()
                } label: {
                    Label("拍照", systemImage: "camera.circle")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 0)

                if let image = lastPhoto {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4), lineWidth: 1))
                        .accessibilityLabel("最新拍攝縮圖")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            // 讀取 database
            vm.loadDatabaseIfNeeded()

            // 每次回到此頁都重新建立一條新的 embeddings stream，
            // 讓消費端的 for-await 能可靠重啟；Camera 本身不會重開。
            let stream = AsyncStream<[Float32]> { continuation in
                camera.attachEmbedding(continuation: continuation)
                // 僅在尚未啟動時才會真正啟動相機
                camera.startIfNeeded()
            }
            vm.embeddings = stream
            vm.streamID = UUID()

            // 只在第一次載入時建立與預熱 CLIP 模型、 visionKit 也在這裡預載
            if !vm.didLoadExtractor {
                Task.detached(priority: .userInitiated) {
                    let remover = await BackgroundRemoverVK()
                    let extractor = CLIPFeatureExtractor()
                    // 預熱：讓第一次推論不卡
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 224, height: 224))
                    let warmup = renderer.image { _ in
                        UIColor.black.setFill()
                        UIBezierPath(rect: CGRect(x: 0, y: 0, width: 224, height: 224)).fill()
                    }
                    _ = extractor.embedding(for: warmup)
                    await MainActor.run {
                        camera.backgroundRemoverVK = remover
                        camera.clipExtractor = extractor
                        vm.didLoadExtractor = true
                    }
                }
            }

            camera.onSessionReady = { session in
                DispatchQueue.main.async {
                    self.vm.captureSession = session
                }
            }
            camera.onPhotoReady = { data in
                self.lastPhoto = data.1
                Task {
                    await self.vm.search(query: data.0)
                }
            }
            
            camera.backgroundRemove = { image in
                self.resultImage = image
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
    let stream: AsyncStream<[Float32]>
    let id: UUID

    var body: some View {
        Text("攝影機已啟動")
            .task(id: id) {
                var idx = 0
                for await vec in stream {
                    idx += 1
//                    print("[UI] got embedding #\(idx), dim=\(vec.count)")
                }
            }
    }
}
