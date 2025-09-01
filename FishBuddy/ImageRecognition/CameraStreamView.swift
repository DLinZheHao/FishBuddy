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
    @ObservedObject private var vm = CameraStreamVM()
    @State private var lastPhoto: UIImage?
    
    typealias CaptureMode = CameraStreamVM.CaptureMode
    
    var body: some View {
        VStack {
            // 穩定掛載 Preview；session 之後可遲到更新
            ZStack {
                CameraPreview(session: vm.captureSession)
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
            .id(camera.captureSession.map { ObjectIdentifier($0) }) // ObjectIdentifier 是一種「以物件記憶體身份作為唯一值」的東西
            .padding(.horizontal)
            
            HStack {
                Button {
                    camera.capturePhoto()
                } label: {
                    Label("拍照", systemImage: "camera.circle")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)

                Spacer()

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
            .padding(.horizontal)
            
            // 切換前/後鏡頭
            Toggle("後鏡頭", isOn: Binding(
                get: { camera.backCamera },
                set: { camera.backCamera = $0 }
            ))
            .padding()

            Spacer()
            
//            Picker("Mode", selection: $vm.mode) {
//                Text("Stream").tag(CaptureMode.stream)
//                Text("Photo").tag(CaptureMode.photo)
//            }
//            .pickerStyle(.segmented)
//            .onChange(of: vm.mode) { mode in
//                camera.setMode(mode)
//            }
            
            // 用 Task 讀取 embedding
            if let embeddings = vm.embeddings {
                EmbeddingConsumer(stream: embeddings, id: vm.streamID)
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
            vm.embeddings = stream
            vm.streamID = UUID()

            // 只在第一次載入時建立與預熱 CLIP 模型
            if !vm.didLoadExtractor {
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
                        vm.didLoadExtractor = true
                    }
                }
            }

            camera.onSessionReady = { session in
                DispatchQueue.main.async {
                    self.vm.captureSession = session
                }
            }
            camera.onPhotoReady = { image in
                self.lastPhoto = image
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
