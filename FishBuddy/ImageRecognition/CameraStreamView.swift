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
    /// 顯示使用教學
    @State private var showHelp = false
    /// 顯示 toast
    @State private var showToast = false
    /// 顯示 toast 文字
    @State private var toastMessage = ""
    
    /// 回去天氣頁面的閉包
    var onClose: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 整個鏡頭預覽區域
                ZStack(alignment: .topLeading) {
                    // 鏡頭畫面
                    CameraPreview(session: vm.captureSession, camera: camera)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                    // 瞄準框
                    FramingGuide(
                        aspect: .wide43,
                        onRectChange: { norm in
                            // 連續調整時即時同步到 CameraController 的 ROI 與疊畫
                            camera.cropRectNormalized = norm
                            camera.updateCropOverlayFromStoredROI()
                        },
                        onCenterTap: { pointInView, rect in
                            // 點中心時開始追蹤（rect 已是 0..1 正規化）
                            camera.startTracking(withNormalizedBox: rect)
                        },
                        onZoomChange: { scale in
                            camera.updateZoom(scale)
                        },
                        onZoomEnd: {
                            vm.lastZoomFactor = camera.currentZoomFactor
                        },
                        targetMode: $vm.targetMode,
                        cropBoxInView: $camera.cropBoxInView,
                        trackedBoxInView: $camera.trackedBoxInView,
                        isAdjusting: $vm.isInAdjustFrameMode,
                        lastZoomFactor: $vm.lastZoomFactor
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 充滿與預覽同大小
                    .ignoresSafeArea()
                    .zIndex(1) // 確保在預覽上層
                    
                    // 左上角：功能說明（tooltip/popover）
                    Button {
                        showHelp.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                    .zIndex(2) // 讓按鈕在 FramingGuide 之上，避免被攔截手勢
                    .popover(isPresented: $showHelp, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📌 功能說明")
                                .font(.headline)
                            Text("1. 對準要辨識的物體\n2. 點擊『拍照』開始辨識\n3. 下方可切換模式")
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(width: 220)
                        .presentationCompactAdaptation(.popover) // 適應動畫模式
                    }
                }
                // 當換成「新的」AVCaptureSession 實例時，強制 SwiftUI 重新建構預覽（每次切換都會開啟新的 session）
                .id(camera.captureSession.map { ObjectIdentifier($0) }) // ObjectIdentifier 是一種「以物件記憶體身份作為唯一值」的東西
                // 進度指示：以「相機/模型就緒」為條件顯示
                .overlay(alignment: .center) {
                    if vm.captureSession == nil || !vm.didLoadExtractor {
                        ProgressView("啟動相機中…")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .transition(.opacity)
                    }
                }

                // Overlay UI - 攝像畫面上的物件都在這裡
                VStack {
                    Spacer()

                    // 搜尋結果顯示
                    ZStack(alignment: .bottom) {
                        VStack {
                            Spacer()
                            VStack(spacing: 16) {
                                SideButton(icon: "viewfinder", title: "Lock Target", isActive: vm.targetMode.isAutoTracking()) {
                                    vm.cycleTargetMode()
                                }
                                
                                SideButton(icon: "camera.rotate", title: "Switch\nCamera", isActive: !camera.backCamera) {
                                    camera.backCamera.toggle()
                                }
                                
                                SideButton(icon: "slider.horizontal.3", title: "Adjust\nMode", isActive: vm.isInAdjustFrameMode) {
                                    vm.isInAdjustFrameMode.toggle()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        
                        if let results = vm.imageSearchResult, !results.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("搜尋結果")
                                        .font(.headline)
                                        .padding(.bottom, 4)
                                    
                                    Spacer()
                                    
                                    // 關閉按鈕（叉叉）
                                    Button {
                                        vm.imageSearchResult = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                            .accessibilityLabel("關閉搜尋結果")
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                ForEach(Array(results.prefix(3)), id: \.0.taxonId) { (item, score) in
                                    NavigationLink {
                                        TaxonDetailView(taxon: item)
                                            .navigationBarTitleDisplayMode(.inline)
                                    } label: {
                                        SearchResultRow(
                                            imageURL: URL(string: item.photos?.first?.url ?? ""),
                                            title: item.commonName ?? "",
                                            idText: "ID: \(item.taxonId)",
                                            scoreText: String(format: "相似度: %.2f", score)
                                        )
                                    }
                                    .buttonStyle(.plain) // 保留自訂列外觀
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                    }
                    
                    CaptureToolbar(
                        lastPhoto: lastPhoto,
                        onCapture: { handleCaptureTapped() },
                        onClose: onClose ?? {},
                        zoom: camera.currentZoomFactor
                    )
                    .padding(.bottom, 16)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .toast(
                isPresented: $showToast,
                message: toastMessage,
                duration: 1.6
            )
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
                
                camera.bindTargetMode($vm.targetMode)
                
                camera.resume()
            }
            .onDisappear {
                // 在 Tab 切換時不要停止相機與釋放資源，避免重建成本
                camera.pause()
            }
        }
    }
    
    /// 管理拍照按鍵點擊
    private func handleCaptureTapped() {
        // 這裡可以依照你的 TargetMode 設計來改判斷邏輯
        switch vm.targetMode {
        case .manualAim, .autoTracking(.tracking):
            camera.capturePhoto()
        case .autoTracking(.losting):
            toastMessage = "目標已遺失，請重新鎖定再拍照"
            withAnimation {
                showToast = true
            }
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
    weak var camera: CameraController?
    
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView(frame: .zero)
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let camera = camera {
            camera.attachPreviewLayer(v.videoPreviewLayer)
        }
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
        // 不顯示任何內容，只負責消費 stream
        EmptyView()
            .task(id: id) {
                var idx = 0
                for await vec in stream {
                    idx += 1
                    print("[UI] got embedding #\(idx), dim=\(vec.count)")
                    // 在這裡處理 vec
                }
            }
    }
}

#if DEBUG
//// MARK: - Preview
//#Preview("CameraStreamView") {
//    // 用 Preview 專用的 wrapper，避免在預覽時啟動實際相機與模型
//    CameraStreamPreviewWrapper()
//}
//
///// 一個輕量的 wrapper，提供假資料並關閉相機啟動流程
//private struct CameraStreamPreviewWrapper: View {
//    @StateObject private var camera = CameraController()
//    @StateObject private var vm = CameraStreamVM()
//
//    var body: some View {
//        NavigationStack {
//            CameraStreamView(onClose: {})
//                .onAppear {
//                    // 預覽中：不要啟動相機與模型，僅提供假 UI 狀態
//                    vm.didLoadExtractor = true
//                    // 不要真的把 session 丟進去，避免要求權限
//                    vm.captureSession = nil
//
//                    // 準備假搜尋結果讓下方卡片可見
//                    let mock = TaxonItem.previewMock
//                    vm.imageSearchResult = [
//                        (mock, 98.2),
//                        (mock, 92.7),
//                        (mock, 88.5)
//                    ]
//                }
//        }
//        // 將 ViewModel 狀態注入到真正的 CameraStreamView 內部
//        // 這裡用環境物件注入不適用，因為 CameraStreamView 內部自行持有 @ObservedObject。
//        // 若要更精準控制，可改為在 CameraStreamView 提供 init(vm:camera:onClose:) 以便預覽注入。
//    }
//}
#endif

//@Environment(\.scenePhase) private var scenePhase
//
//var body: some View {
//    ZStack { ... }
//    .onAppear { camera.startIfNeeded() }
//    .onDisappear { camera.stop() }
//    .onChange(of: scenePhase) { newPhase in
//        switch newPhase {
//        case .background, .inactive:
//            camera.stop()
//        case .active:
//            camera.startIfNeeded()
//        default:
//            break
//        }
//    }
//}
