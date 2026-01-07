//
//  CameraController.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/8/28.
//
import SwiftUI
import AVFoundation
import CoreImage
import UIKit
import Photos

/// 相機捕捉模式
enum TargetMode: Equatable {
    /// 自動追蹤 -> 追蹤框輸出
    case autoTracking(AutoState)
    /// 手動拍照 -> 瞄準框內容輸出
    case manualAim
    
    func isAutoTracking() -> Bool {
        switch self {
        case .autoTracking(_):
            return true
        case .manualAim:
            return false
        }
    }
    
    func isLosingTarget() -> Bool {
        switch self {
        case .autoTracking(let type):
            switch type {
            case .losting: return true
            case .tracking: return false
            }
        case .manualAim:
             return false
        }
    }
}

enum AutoState {
    /// 追蹤中
    case tracking
    /// 失去目標
    case losting
}

@MainActor
protocol CameraControllerOutputs {
    var onSessionReady: ((AVCaptureSession) -> Void)? { get set }
    var onPhoto: ((UIImage) -> Void)? { get set }   // 拍照完成回呼（新）
}

// CameraController 負責管理相機的存取、權限、相機切換、相機資料流的取得與釋放等功能
final class CameraController: NSObject, ObservableObject {
    // MARK: - Debug
    private let enableCoordDebugLogs: Bool = true
    private func dbg(_ message: String) {
        guard enableCoordDebugLogs else { return }
        print(message)
    }
    /// 設定相機捕捉模式，預設，綁定後清出預設
    private var targetModeBinding: Binding<TargetMode> = .constant(.manualAim)
    
    /// 目前使用中的相機裝置（後鏡頭 / 前鏡頭）
     var captureDevice: AVCaptureDevice?
    
    /// 背景去除用物件
    var backgroundRemoverVK: BackgroundRemoverVK?
    // 由外部注入或稍後設定的 CLIP 特徵擷取器
    var clipExtractor: CLIPFeatureExtractor?
    // 重用 CIContext（優先用 Metal）避免每幀建立花費：截取照片用的渲染器
    private var ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        } else {
            return CIContext(options: nil)
        }
    }()
    
    // 專用推論佇列，避免阻塞相機輸出回呼
    private let inferenceQueue = DispatchQueue(label: "inferenceQueue")
    // session 的專用序列，確保相機操作執行緒安全
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    // 送出可跨執行緒的資料：[Float]（CLIP 向量）
    private var embeddingContinuation: AsyncStream<[Float]>.Continuation?
    
    // 簡單節流：以時間為準（每 ≥150ms 才做一次推論）
    private var lastInferenceTime = DispatchTime.now()
    private let minInferenceIntervalNS: UInt64 = 150_000_000 // 150ms

    // Still-photo output（拍照輸出）
    private var photoOutput: AVCapturePhotoOutput?

    /// 相機/照片畫質設定（可在執行中調整）
    public var videoPreset: AVCaptureSession.Preset = .high   // ✅ 預覽/串流解析度（優先給 PreviewLayer）
    public var enableHighResolutionPhoto: Bool = true               // 是否啟用高解析度拍照
    public var photoQualityPrioritization: AVCapturePhotoOutput.QualityPrioritization = .quality // 以品質優先


    /// ✅ 讓系統自動管理 HDR（EDR）串流。強制 HDR 常會讓畫面看起來更暗。
    public var allowAutoHDR: Bool = true

    /// ✅ 目標預覽 FPS（搭配低光時允許降 FPS 的設定）。
    public var previewMaxFPS: Double = 30
    public var previewMinFPSInLowLight: Double = 15

    // 相機的 session 實體，負責管理輸入與輸出
    var captureSession: AVCaptureSession? {
        didSet {
            guard let captureSession else { return }
            onSessionReady?(captureSession)
        }
    }

    // 控制目前是否使用後鏡頭，true 表示使用後鏡頭，false 表示前鏡頭
    // 當此屬性變動時，會自動停止並重新啟動相機以切換鏡頭
    public var backCamera = true {
        didSet {
            // 鏡頭切換時先停止當前 session，再重新啟動
            stop()
            start()
        }
    }

    // 用來記錄是否已獲得相機權限
    private var permissionGranted = true
    // 紀錄相機是否正在運行，避免重複啟動
    private(set) var isRunning: Bool = false

    /// 與此控制器相連的預覽層（用於把畫面座標換算成相機裝置座標）
    weak var previewLayer: AVCaptureVideoPreviewLayer?

    /// 追蹤物件
    let tracker = AnimalTracker()
    // 如果你要給 SwiftUI 畫框，可以準備一個 published
    @Published var trackedBoxInView: CGRect?  // 這個是「畫面座標的框」
    /// 將要實際裁切的區塊（以預覽層座標表示，供 SwiftUI 疊畫使用）
    @Published var cropBoxInView: CGRect? = nil
    /// 當 session 準備完成後，回傳
    var onSessionReady: ((AVCaptureSession) -> Void)?
    
    /// 當拍完照後的回傳 -> 回傳處理過的 embeeding
    var onPhotoReady: ((([Float], UIImage)) -> Void)?
    
    /// 測試拍照完後，背景的切割結果
    var backgroundRemove: ((UIImage) -> Void)?
    
    /// 使用者設定的裁切框（Preview/UI 正規化座標；原點左上；x,y,w,h ∈ 0...1）。
    /// 注意：這不是 metadataRect；它是相對於 previewLayer.bounds 的 0..1。
    /// nil 代表不裁切。
    @Published var cropRectNormalized: CGRect? = nil
    /// 使用者設定的裁切框中心，用來對焦
    @Published var cropRectCenter: CGPoint? = nil
    /// 目前放大比率
    @Published var currentZoomFactor: CGFloat = 1.0

    /// 手動近拍模式：true 優先使用 Ultra Wide（近距離更容易對焦）；false 使用 Wide（畫質較佳）
//    @Published var preferMacro: Bool = false {
//        didSet {
//            // 切換鏡頭策略需要重建 session
//            stop()
//            start()
//        }
//    }
    
    /// 追蹤框（metadataRect 空間；0..1；原點左上）。由 tracker.onUpdate 產生。
    @Published var trackedBoxNormalized: CGRect?
    
    override init() {
        super.init()
        setupTrackerCallbacks()
    }
    
    func bindTargetMode(_ binding: Binding<TargetMode>) {
        self.targetModeBinding = binding
    }
    
    private func setupTrackerCallbacks() {
        tracker.onUpdate = { [weak self] visionRect in
            guard let self,
                  let layer = self.previewLayer else { return }
            
            let metadataRect = CGRect(
                x: visionRect.origin.x,
                y: 1.0 - visionRect.origin.y - visionRect.height,
                width: visionRect.width,
                height: visionRect.height
            )
            
            Task { @MainActor in
                self.trackedBoxNormalized = metadataRect
            }
            
            let rectInLayer = layer.layerRectConverted(fromMetadataOutputRect: metadataRect)
            
            Task { @MainActor in
                self.trackedBoxInView = rectInLayer
            }
        }
        
        tracker.onLost = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // 例如：追蹤失敗就把模式改成 idle
                self.targetModeBinding.wrappedValue = TargetMode.autoTracking(.losting)
            }
        }
    }
    
    /// 由 UI 設定 / 清除裁切框（在主執行緒呼叫）
    func startTracking(withNormalizedBox norm: CGRect) {
        guard let layer = previewLayer else { return }
        dbg("[ROI] startTracking inputNorm(UI 0..1, top-left)=\(norm) layerBounds=\(layer.bounds) gravity=\(layer.videoGravity)")
        // 1️⃣ normalized (0..1, UI) → layer 座標
        let layerRect = CGRect(
            x: norm.origin.x * layer.bounds.width,
            y: norm.origin.y * layer.bounds.height,
            width: norm.size.width * layer.bounds.width,
            height: norm.size.height * layer.bounds.height
        )
        dbg("[ROI] layerRect(points)=\(layerRect)")
        // Store preview-normalized ROI for manualAim still-photo cropping.
        cropRectNormalized = norm

        // 2️⃣ layer rect → metadata rect (0..1, top-left，含 .resizeAspectFill 的裁切資訊)
        let metadataRect = layer.metadataOutputRectConverted(fromLayerRect: layerRect)
        dbg("[ROI] metadataRect(0..1, top-left)=\(metadataRect)")

        // 立即把「手動裁切框（preview-normalized）」回繪到預覽層上，供 UI 疊畫
        let overlayRect = layerRect
        dbg("[ROI] overlayRect(points, fromPreviewNorm)=\(overlayRect)")
        DispatchQueue.main.async { [weak self] in
            self?.cropBoxInView = overlayRect
        }
        
        // 3️⃣ metadata rect → Vision rect (0..1, bottom-left)
        let visionRect = CGRect(
            x: metadataRect.origin.x,
            y: 1.0 - metadataRect.origin.y - metadataRect.height,
            width: metadataRect.width,
            height: metadataRect.height
        )
        dbg("[ROI] visionRect(0..1, bottom-left)=\(visionRect)")
        // 4️⃣ 丟給你的 AnimalTracker.startTracking(initialBoundingBox:)
        tracker.startTracking(initialBoundingBox: visionRect)
        targetModeBinding.wrappedValue = .autoTracking(.tracking)
    }

    public func updateCropOverlayFromStoredROI() {
        guard let layer = previewLayer else {
            DispatchQueue.main.async { [weak self] in self?.cropBoxInView = nil }
            return
        }
        guard let roi = cropRectNormalized else {
            DispatchQueue.main.async { [weak self] in self?.cropBoxInView = nil }
            return
        }

        // roi is preview-normalized (0..1, top-left). Convert to layer points directly.
        let overlayRect = CGRect(
            x: roi.origin.x * layer.bounds.width,
            y: roi.origin.y * layer.bounds.height,
            width: roi.size.width * layer.bounds.width,
            height: roi.size.height * layer.bounds.height
        )

        dbg("[ROI] updateCropOverlay stored previewNorm=\(roi) layerBounds=\(layer.bounds)")
        dbg("[ROI] updateCropOverlay overlayRect(points)=\(overlayRect)")

        DispatchQueue.main.async { [weak self] in
            self?.cropBoxInView = overlayRect
        }
    }
    
    /// 由 UI 傳入正在顯示的預覽層，供座標轉換使用
    public func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        Task { @MainActor in
            self.previewLayer = layer
            self.dbg("[PreviewLayer] attached videoGravity=\(layer.videoGravity) bounds=\(layer.bounds) connection=\(String(describing: layer.connection))")
            // Bounds may be .zero until layout; log again on next runloop.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.dbg("[PreviewLayer] post-layout bounds=\(layer.bounds) frame=\(layer.frame)")
            }
            self.updateCropOverlayFromStoredROI()
        }
    }
    
//    •    在 CameraController 裡面用了 AsyncStream<CMSampleBuffer> 來建立一個非同步的影格（frame）資料流。
//    •    Swift 在建立 AsyncStream 時，會給你一個 Continuation 物件。
//    •    這個 Continuation 就像一個「入口」，你可以用它來 往外部正在監聽的 AsyncStream 送資料。
    // 外部附加接收嵌入向量的 continuation（而非直接暴露 CMSampleBuffer）
    public func attachEmbedding(continuation: AsyncStream<[Float]>.Continuation) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.embeddingContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                // 當消費端（UI）被取消時，清掉舊的 continuation，避免後續 yield 到無人接收
                self.sessionQueue.async { [weak self] in
                    self?.embeddingContinuation = nil
                }
            }
        }
    }

    // 將 embeddingContinuation 設為 nil，代表停止將向量資料送出
    public func detatch() {
        sessionQueue.async {
            self.embeddingContinuation = nil
        }
    }

    // 停止相機 session，並釋放資源
    public func stop() {
        sessionQueue.sync { [self] in
            captureSession?.stopRunning() // 停止影像擷取
            captureSession = nil // 釋放 session
            captureDevice = nil
            isRunning = false
        }
    }

    /// 暫停相機 session（不銷毀，僅停止）
    public func pause() {
        sessionQueue.async { [weak self] in
            guard let self, let session = self.captureSession, self.isRunning else { return }
            session.stopRunning()
            self.isRunning = false
        }
    }

    /// 恢復相機 session（若尚未建立則重建）
    public func resume() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let session = self.captureSession, !self.isRunning {
                session.startRunning()
                self.isRunning = true
            } else if self.captureSession == nil {
                let captureSession = AVCaptureSession()
                self.captureSession = captureSession
                self.checkPermission()
                self.setupCaptureSession(position: self.backCamera ? .back : .front)
                captureSession.startRunning()
                self.isRunning = true
            }
        }
    }

    // 啟動相機 session，並設定相關參數與權限
    public func start() {
        sessionQueue.async { [self] in
            let captureSession = AVCaptureSession()
            self.captureSession = captureSession
            self.checkPermission() // 檢查是否有權限
            self.setupCaptureSession(position: backCamera ? .back : .front) // 設定鏡頭
            captureSession.startRunning() // 開始擷取影像
            isRunning = true
        }
    }

    /// 動態切換串流畫質（解析度）。若裝置不支援則維持原本設定。
    public func setVideoPreset(_ preset: AVCaptureSession.Preset) {
        sessionQueue.async { [weak self] in
            guard let self, let session = self.captureSession, session.canSetSessionPreset(preset) else { return }
            session.beginConfiguration()
            session.sessionPreset = preset
            session.commitConfiguration()
            self.videoPreset = preset
        }
    }

    // 設定相機畫面旋轉方向，根據裝置的方向調整輸出影像角度
    private func setOrientation(_ orientation: UIDeviceOrientation) {
        guard let captureSession else { return }

        // 根據裝置方向決定旋轉角度
        let angle: Double?
        switch orientation {
        case .unknown, .faceDown:
            angle = nil // 未知或朝下不設定旋轉
        case .portrait, .faceUp:
            angle = 90 // 直立或螢幕朝上
        case .portraitUpsideDown:
            angle = 270 // 直立顛倒
        case .landscapeLeft:
            angle = 0 // 橫向左
        case .landscapeRight:
            angle = 180 // 橫向右
        @unknown default:
            angle = nil
        }

        // 設定所有輸出的 videoRotationAngle
        if let angle {
            for output in captureSession.outputs {
                output.connection(with: .video)?.videoRotationAngle = angle
            }
        }
    }

    // 檢查相機權限，根據狀態決定是否要請求權限
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 使用者已授權相機權限
            self.permissionGranted = true
        case .notDetermined:
            // 尚未詢問權限，發起請求
            self.requestPermission()
        // 其他情況（.denied, .restricted），直接設為未授權
        default:
            self.permissionGranted = false
        }
    }

    // 請求相機權限，結果回傳後更新 permissionGranted 狀態
    func requestPermission() {
        // 這裡使用 unowned self，避免強參考循環
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
        }
    }

    //    可以把 setupCaptureSession 想成「搭舞台」：
    //        •    AVCaptureSession → 整個舞台。
    //        •    AVCaptureDeviceInput → 麥克風（相機裝置），讓舞台有輸入。
    //        •    AVCaptureVideoDataOutput → 音響喇叭（輸出），讓東西能傳出去。
    //        •    canAddInput / canAddOutput → 檢查舞台是否能裝下這些設備。
    //        •    delegate → 音控人員，持續監聽並把聲音（這裡是影像）丟給外部。
    // 設定相機 session 的輸入與輸出，並處理權限、裝置選擇、輸入、輸出等流程
    func setupCaptureSession(position: AVCaptureDevice.Position) {
        guard let captureSession else { return }

        // ✅ 將多個 session 設定合併成一次提交，避免中途狀態不一致（切鏡頭/重建時更穩）
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // ✅ 保險：避免重複疊加 input/output（就算你目前每次都 new session，這樣也更安全）
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // 若無權限則直接返回
        guard permissionGranted else {
            print("No permission for camera")
            return
        }

        // ✅ PreviewLayer 品質優先：先用 `.high`（穩定、接近 Camera.app preview pipeline）
        // `.photo` 在某些機型的 preview pipeline 不一定更好；`4K` 也可能導致效能/曝光策略改變。
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
            self.videoPreset = .high
        } else if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
            self.videoPreset = .photo
        }

        print("[Camera] sessionPreset=\(captureSession.sessionPreset.rawValue)")

        // 建立影像輸出物件
        let videoOutput = AVCaptureVideoDataOutput()
        // ⚠️ 注意：VideoDataOutput 只影響你的推論/處理，不影響使用者看到的 PreviewLayer。
        // 使用 NV12 FullRange（420f）通常效能最好；CIImage/Vision 也可直接吃。
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true

        // 搜尋指定位置（前/後鏡頭）可用的相機裝置（亮度/畫質優先）
        let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                // ✅ Virtual devices first: these can automatically switch Wide/Tele/UltraWide for better zoom quality
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,

                // Fallbacks
                .builtInWideAngleCamera,
                .builtInTelephotoCamera,
                .builtInUltraWideCamera
            ],
            mediaType: .video,
            position: position
        )

        let devices = videoDeviceDiscoverySession.devices
        let preferred: AVCaptureDevice? = {
            // Front camera: usually only wide
            if position != .back {
                return devices.first
            }

            // Back camera:
            // 1) Default (quality + zoom): pick a VIRTUAL device first so iOS can switch lenses when you zoom.
            // 2) Macro mode: if user explicitly wants macro, prefer UltraWide (close focus), else virtual.
//            if preferMacro {
//                return devices.first { $0.deviceType == .builtInUltraWideCamera }
//                    ?? devices.first { $0.deviceType == .builtInTripleCamera }
//                    ?? devices.first { $0.deviceType == .builtInDualWideCamera }
//                    ?? devices.first { $0.deviceType == .builtInDualCamera }
//                    ?? devices.first { $0.deviceType == .builtInWideAngleCamera }
//            } else {
                return devices.first { $0.deviceType == .builtInTripleCamera }
                    ?? devices.first { $0.deviceType == .builtInDualWideCamera }
                    ?? devices.first { $0.deviceType == .builtInDualCamera }
                    ?? devices.first { $0.deviceType == .builtInWideAngleCamera }
//            }
        }()

        guard let videoDevice = preferred else {
            print("Unable to find video device")
            return
        }

        self.captureDevice = videoDevice

        // ✅ Auto Focus / Auto Exposure
        do {
            try videoDevice.lockForConfiguration()
            defer { videoDevice.unlockForConfiguration() }

            if #available(iOS 13.0, *) {
                videoDevice.automaticallyAdjustsVideoHDREnabled = true
            }

            if videoDevice.isLowLightBoostSupported {
                videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoDevice.focusMode = .continuousAutoFocus
            } else if videoDevice.isFocusModeSupported(.autoFocus) {
                videoDevice.focusMode = .autoFocus
            }

            if videoDevice.isAutoFocusRangeRestrictionSupported {
                videoDevice.autoFocusRangeRestriction = .near
            }

            if videoDevice.isSmoothAutoFocusSupported {
                videoDevice.isSmoothAutoFocusEnabled = true
            }

            if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                videoDevice.exposureMode = .continuousAutoExposure
            }

            videoDevice.isSubjectAreaChangeMonitoringEnabled = true

            let center = CGPoint(x: 0.5, y: 0.5)
            if videoDevice.isFocusPointOfInterestSupported {
                videoDevice.focusPointOfInterest = center
            }
            
            if videoDevice.isExposurePointOfInterestSupported {
                videoDevice.exposurePointOfInterest = center
            }

            if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }

        } catch {
            print("Failed to lock device for configuration: \(error)")
        }

        // 建立裝置輸入
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Unable to create AVCaptureDeviceInput")
            return
        }

        guard captureSession.canAddInput(videoDeviceInput) else {
            print("Unable to add input")
            return
        }
        captureSession.addInput(videoDeviceInput)

        // ✅ 設定影像輸出的 delegate 與處理隊列
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))

        guard captureSession.canAddOutput(videoOutput) else {
            print("Unable to add video output")
            return
        }
        captureSession.addOutput(videoOutput)

        if let conn = videoOutput.connection(with: .video) {
            // ✅ 影像防手震（支援才開）
            if conn.isVideoStabilizationSupported {
                // ⚠️ AVCaptureConnection 沒有 supportedVideoStabilizationModes。
                // Apple 建議用「device.activeFormat 是否支援該 mode」來判斷。
                // 參考：AVCaptureDeviceFormat.isVideoStabilizationModeSupported(_:)。
                if videoDevice.activeFormat.isVideoStabilizationModeSupported(.standard) {
                    conn.preferredVideoStabilizationMode = .standard
                } else {
                    conn.preferredVideoStabilizationMode = .auto
                }
            }
            // HDR 不在 AVCaptureConnection 上設定；已在 device.lockForConfiguration() 內處理。
        }

        // 新增拍照輸出（不影響既有串流流程）
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
        } else {
            print("Unable to add photo output")
        }
    }
    
    // 僅在尚未啟動時才會真正啟動相機
    public func startIfNeeded() {
        if !isRunning {
            start()
        }
    }
    
    /// 鏡頭放大縮小
    func updateZoom(_ zoomFactor: CGFloat) {
        let factor = zoomFactor
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.captureDevice
            else { return }
            
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            let newZoom = max(minZoom, min(factor, maxZoom))
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoom
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentZoomFactor = newZoom
                }
            } catch {
                print("Zoom failed: \(error)")
            }
        }
    }
    
    /// 將 UIImage 轉為「已套用方向」的位圖（.up），避免裁切時座標錯亂
    private func imageByFixingOrientation(_ image: UIImage) -> UIImage {
        // 若圖片本身的方向就是 .up（代表位圖像素已符合直立方向），直接回傳，避免不必要的重繪成本
        if image.imageOrientation == .up { return image }
        // 取得目前圖片的邏輯尺寸（point 為單位，會搭配 scale 轉為像素繪製）
        let size = image.size
        // 建立一個新的位圖繪圖環境：
        // - size: 以圖片原始尺寸繪製
        // - opaque: false（保留透明通道）
        // - scale: 使用原圖的 scale，確保輸出解析度一致（例如 @2x/@3x）
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        // 將原圖以「忽略 EXIF 方向」的方式，直接繪製到新的畫布。
        // UIKit 會把像素內容依當前繪圖座標系重排，輸出得到的影像方向即為 .up
        image.draw(in: CGRect(origin: .zero, size: size))
        // 從目前的繪圖內容取出 UIImage；若意外失敗（理論上少見），就回傳原圖以保底
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        // 結束繪圖環境，釋放資源
        UIGraphicsEndImageContext()
        // 回傳「方向已被固定為 .up」的新圖，後續做裁切/像素座標換算時就不會因方向而錯位
        return normalized
    }

    /// 將相對座標的裁切框（0..1；原點左上）轉為像素座標
    private func pixelRect(for normalized: CGRect, width: Int, height: Int) -> CGRect {
        let nx = max(0, min(1, normalized.origin.x))
        let ny = max(0, min(1, normalized.origin.y))
        let nw = max(0, min(1 - nx, normalized.size.width))
        let nh = max(0, min(1 - ny, normalized.size.height))
        let x = CGFloat(width) * nx
        let y = CGFloat(height) * ny
        let w = CGFloat(width) * nw
        let h = CGFloat(height) * nh
        return CGRect(x: x.rounded(.towardZero), y: y.rounded(.towardZero),
                      width: w.rounded(.towardZero), height: h.rounded(.towardZero))
    }

    /// Clamp a rect to the image bounds.
    private func clampPixelRect(_ rect: CGRect, imageWidth: Int, imageHeight: Int) -> CGRect {
        let x0 = max(0, min(CGFloat(imageWidth), rect.minX))
        let y0 = max(0, min(CGFloat(imageHeight), rect.minY))
        let x1 = max(0, min(CGFloat(imageWidth), rect.maxX))
        let y1 = max(0, min(CGFloat(imageHeight), rect.maxY))
        let w = max(0, x1 - x0)
        let h = max(0, y1 - y0)
        return CGRect(x: x0.rounded(.towardZero), y: y0.rounded(.towardZero),
                      width: w.rounded(.towardZero), height: h.rounded(.towardZero))
    }

    /// Convert a preview-normalized rect (0..1 in previewLayer.bounds, top-left) into a pixel rect in the final still photo,
    /// assuming the preview uses `.resizeAspectFill`.
    private func pixelRectFromPreviewNormalized(
        _ previewNorm: CGRect,
        previewSize: CGSize,
        imageWidth: Int,
        imageHeight: Int
    ) -> CGRect {
        // Convert normalized -> preview points
        let r = CGRect(
            x: previewNorm.origin.x * previewSize.width,
            y: previewNorm.origin.y * previewSize.height,
            width: previewNorm.size.width * previewSize.width,
            height: previewNorm.size.height * previewSize.height
        )

        // AspectFill geometry: scale image to cover preview, then center-crop.
        let iw = CGFloat(imageWidth)
        let ih = CGFloat(imageHeight)
        let pw = previewSize.width
        let ph = previewSize.height
        guard iw > 0, ih > 0, pw > 0, ph > 0 else { return .zero }

        let scale = max(pw / iw, ph / ih)
        let displayW = iw * scale
        let displayH = ih * scale
        let offsetX = (pw - displayW) / 2.0
        let offsetY = (ph - displayH) / 2.0

        // Map preview points back to image pixels.
        let x = (r.minX - offsetX) / scale
        let y = (r.minY - offsetY) / scale
        let w = r.width / scale
        let h = r.height / scale

        let pixel = CGRect(x: x, y: y, width: w, height: h)
        return clampPixelRect(pixel, imageWidth: imageWidth, imageHeight: imageHeight)
    }

    /// Crop still photo using preview-normalized ROI under `.resizeAspectFill`.
    private func cropUsingPreviewNormalized(_ image: UIImage, previewNorm: CGRect) -> UIImage? {
        guard let layer = previewLayer else {
            dbg("[Crop] previewLayer is nil; cannot map preview ROI")
            return nil
        }
        guard let cg = image.cgImage else { return nil }

        let previewSize = layer.bounds.size
        let pr = pixelRectFromPreviewNormalized(previewNorm, previewSize: previewSize, imageWidth: cg.width, imageHeight: cg.height)

        dbg("[Crop][AspectFill] previewBounds=\(layer.bounds) previewNorm=\(previewNorm)")
        dbg("[Crop][AspectFill] imagePx=\(cg.width)x\(cg.height) -> pixelRect(px)=\(pr)")

        guard pr.width > 0, pr.height > 0 else { return nil }
        guard let cgCropped = cg.cropping(to: pr) else { return nil }
        return UIImage(cgImage: cgCropped, scale: image.scale, orientation: .up)
    }

    /// Convert a preview-layer POINTS rect into a pixel rect in the final still photo, assuming `.resizeAspectFill`.
    private func pixelRectFromPreviewPoints(
        _ previewPoints: CGRect,
        previewSize: CGSize,
        imageWidth: Int,
        imageHeight: Int
    ) -> CGRect {
        let iw = CGFloat(imageWidth)
        let ih = CGFloat(imageHeight)
        let pw = previewSize.width
        let ph = previewSize.height
        guard iw > 0, ih > 0, pw > 0, ph > 0 else { return .zero }

        let scale = max(pw / iw, ph / ih)
        let displayW = iw * scale
        let displayH = ih * scale
        let offsetX = (pw - displayW) / 2.0
        let offsetY = (ph - displayH) / 2.0

        let x = (previewPoints.minX - offsetX) / scale
        let y = (previewPoints.minY - offsetY) / scale
        let w = previewPoints.width / scale
        let h = previewPoints.height / scale

        let pixel = CGRect(x: x, y: y, width: w, height: h)
        return clampPixelRect(pixel, imageWidth: imageWidth, imageHeight: imageHeight)
    }

    /// Crop still photo using a preview-layer POINTS rect under `.resizeAspectFill`.
    private func cropUsingPreviewPoints(_ image: UIImage, previewPoints: CGRect, tag: String) -> UIImage? {
        guard let layer = previewLayer else {
            dbg("[Crop] previewLayer is nil; cannot map preview points")
            return nil
        }
        guard let cg = image.cgImage else { return nil }

        let previewSize = layer.bounds.size
        let pr = pixelRectFromPreviewPoints(previewPoints, previewSize: previewSize, imageWidth: cg.width, imageHeight: cg.height)

        dbg("[Crop][AspectFill][\(tag)] previewBounds=\(layer.bounds)")
        dbg("[Crop][AspectFill][\(tag)] previewPoints=\(previewPoints)")
        dbg("[Crop][AspectFill][\(tag)] imagePx=\(cg.width)x\(cg.height) -> pixelRect(px)=\(pr)")

        guard pr.width > 0, pr.height > 0 else { return nil }
        guard let cgCropped = cg.cropping(to: pr) else { return nil }
        return UIImage(cgImage: cgCropped, scale: image.scale, orientation: .up)
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // 當有新影格輸出時會呼叫此方法
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // 🔴 這一行是讓 Vision 持續追蹤的關鍵
        if sampleBuffer.isValid, let pixelBuffer = sampleBuffer.imageBuffer {
            tracker.processFrame(pixelBuffer: pixelBuffer)
            // 時間節流：每 ≥150ms 才推一次
            let now = DispatchTime.now()
            guard now.uptimeNanoseconds - lastInferenceTime.uptimeNanoseconds >= minInferenceIntervalNS else { return }
            lastInferenceTime = now
            guard let clip = clipExtractor else { return }
            inferenceQueue.async { [weak self] in
                guard let self else { return }
                // 直接走 CVPixelBuffer → CIImage → CGImage（重用 ciContext）
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                if let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                    let uiImage = UIImage(cgImage: cgImage)
                    if let embedding = clip.multiCropAverageEmbedding(for: uiImage, cropScale: 0.85) {
                        self.embeddingContinuation?.yield(embedding)
                    }
                }
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func capturePhoto(flashMode: AVCaptureDevice.FlashMode = .auto,
                             highResolution: Bool = true) {
        sessionQueue.async { [weak self] in
            guard let self, let photoOutput = self.photoOutput else { return }

            let settings = AVCapturePhotoSettings()

            // 以裝置支援上限為準，避免「高於 maxPhotoQualityPrioritization」造成崩潰
            let desired = self.photoQualityPrioritization
            let maxSupported = photoOutput.maxPhotoQualityPrioritization
            let clamped = AVCapturePhotoOutput.QualityPrioritization(rawValue: min(desired.rawValue, maxSupported.rawValue)) ?? maxSupported
            settings.photoQualityPrioritization = clamped

            // iOS 16+ 不再使用 isHighResolutionPhotoEnabled / isHighResolutionCaptureEnabled。
            // 以 maxPhotoDimensions 控制解析度。
            if highResolution {
                // 使用裝置支援的最大尺寸；如需限制，可在此與自訂上限做最小化處理。
                let maxDimensions = photoOutput.maxPhotoDimensions
                settings.maxPhotoDimensions = maxDimensions
            }

            // 閃光燈（若支援）
            if photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("拍照失敗: \(error)")
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let rawImage = UIImage(data: data) else { return }
        dbg("[Photo] rawImage size(points)=\(rawImage.size) scale=\(rawImage.scale) orientation=\(rawImage.imageOrientation.rawValue)")
        guard let clip = clipExtractor else { return }

        // 先固定方向，再依使用者的裁切框（若有）裁出 ROI
        let base = imageByFixingOrientation(rawImage)
        if let cg = base.cgImage {
            dbg("[Photo] base(.up) cgSize(px)=\(cg.width)x\(cg.height) uiSize(points)=\(base.size) scale=\(base.scale)")
        } else {
            dbg("[Photo] base(.up) has no cgImage")
        }
        let mode = targetModeBinding.wrappedValue
        dbg("[Photo] targetMode=\(mode)")
        let finalImage: UIImage
        // 依照模式切座標
        switch mode {
        case .manualAim:
            if let roi = self.cropRectNormalized {
                dbg("[Photo][manualAim] roiUsed(previewNorm 0..1, top-left)=\(roi)")
                finalImage = cropUsingPreviewNormalized(base, previewNorm: roi) ?? base
            } else {
                finalImage = base
            }
        case .autoTracking(.tracking):
            if let roi = self.trackedBoxNormalized {
                dbg("[Photo][autoTracking] roiUsed(metadataRect 0..1, top-left)=\(roi)")
                if let layer = self.previewLayer {
                    // roi is metadataRect (0..1, top-left). Convert to preview-layer points first.
                    let rectInLayer = layer.layerRectConverted(fromMetadataOutputRect: roi)
                    finalImage = cropUsingPreviewPoints(base, previewPoints: rectInLayer, tag: "autoTracking") ?? base
                } else {
                    finalImage = base
                }
            } else {
                finalImage = base
            }
        case .autoTracking(.losting):
            return
        }
        if let embedding = clip.multiCropAverageEmbedding(for: finalImage, cropScale: 0.85) {
            Task { @MainActor in
                self.onPhotoReady?((embedding, finalImage))
//                saveToPhotoLibrary(finalImage, completion: {_ in })
            }
        }
    }
}

func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
            completion(.failure(NSError(domain: "PhotoAuth", code: 1)))
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if let error = error { completion(.failure(error)); return }
            success ? completion(.success(())) : completion(.failure(NSError(domain: "PhotoSave", code: 2)))
        }
    }
}
