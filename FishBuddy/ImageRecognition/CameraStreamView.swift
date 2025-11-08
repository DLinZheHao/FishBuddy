//
//  ImageRecognitionView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/8/28.
//

import SwiftUI
import AVFoundation
import CoreML
import Kingfisher

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
    /// 拍攝運作模式
    typealias CaptureMode = CameraStreamVM.CaptureMode
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
                    FramingGuide(aspect: .wide43, onCenterTap: { pointInView, rect in
                        camera.startTracking(withNormalizedBox: rect)
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 充滿與預覽同大小
                    .ignoresSafeArea()
                    .zIndex(1) // 確保在預覽上層

                    // animial tracking box
                    if let box = camera.trackedBoxInView {
                        Rectangle()
                            .stroke(lineWidth: 2)
                            .frame(width: box.width, height: box.height)
                            .position(x: box.midX, y: box.midY)
                    }
                    
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

                // Overlay UI
                VStack {
                    HStack(spacing: 8) {
                        Spacer()
                        
                        // 右上角：地圖（push 到 MapView）
                        NavigationLink {
                            TaxonDistributionView(taxonId: 49269)
                                .navigationTitle("地圖")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Image(systemName: "map.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                        .background(.ultraThinMaterial, in: Capsule())
                        
                        // 切換前/後鏡頭
                        Toggle("鏡頭", isOn: Binding(
                            get: { camera.backCamera },
                            set: { camera.backCamera = $0 }
                        ))
                        .labelsHidden() // 隱藏標籤
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                    Spacer()

                    // 搜尋結果顯示
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
                    
                    CaptureToolbar(
                        lastPhoto: lastPhoto,
                        onCapture: { camera.capturePhoto() },
                        onClose: onClose ?? {}
                    )
                    .padding(.bottom, 16)
                }
                .ignoresSafeArea(edges: .bottom)
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
}

// MARK: - 底部工具列（拍照 + 最新縮圖）
private struct CaptureToolbar: View {
    let lastPhoto: UIImage?
    let onCapture: () -> Void
    let onClose: () -> Void

    /// 左右兩側固定寬度，確保快門在幾何正中央
    private let sideWidth: CGFloat = 88

    var body: some View {
        HStack {
            // 左邊區塊：固定 sideWidth，按鈕靠左
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .frame(width: sideWidth, alignment: .leading)

            Spacer(minLength: 0)

            // 中間快門：幾何正中央
            Button(action: onCapture) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle().stroke(Color.black, lineWidth: 2)
                    )
                    .padding(4)
                    .background(
                        Circle()
                            .fill(Color.white) // 塗上想要的顏色
                    )
                    .overlay(
                        Circle().stroke(Color.black, lineWidth: 2)
                    )
            }

            Spacer(minLength: 0)

            // 右邊區塊：固定 sideWidth，縮圖靠右
            HStack {
                Spacer()
                if let image = lastPhoto {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Color.clear
                        .frame(width: 56, height: 56) // 固定 56，避免寬度變來變去
                }
            }
            .frame(width: sideWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 搜尋結果單列：圖片邊長 = 文字區塊高度
private struct SearchResultRow: View {
    let imageURL: URL?
    let title: String
    let idText: String
    let scoreText: String

    @State private var textHeight: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            KFImage(imageURL)
                .placeholder { ProgressView() }
                .cancelOnDisappear(true)
                .resizable()
                .scaledToFill()
                .frame(width: max(textHeight, 1), height: max(textHeight, 1)) // 正方形，避免初始 0 尺吋
                .clipped()
                .cornerRadius(8)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text(idText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(scoreText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            // 量測 VStack 的實際高度
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: TextHeightPreferenceKey.self, value: proxy.size.height)
                }
            )

            Spacer()
        }
        .onPreferenceChange(TextHeightPreferenceKey.self) { h in
            // 更新圖片邊長
            textHeight = h
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.1)))
    }
}

private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
