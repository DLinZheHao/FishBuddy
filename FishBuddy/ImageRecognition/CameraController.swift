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

@MainActor
protocol CameraControllerOutputs {
    var onSessionReady: ((AVCaptureSession) -> Void)? { get set }
    var onPhoto: ((UIImage) -> Void)? { get set }   // 拍照完成回呼（新）
}

// CameraController 負責管理相機的存取、權限、相機切換、相機資料流的取得與釋放等功能
final class CameraController: NSObject, ObservableObject, @unchecked Sendable {

    // 由外部注入或稍後設定的 CLIP 特徵擷取器
    var clipExtractor: CLIPFeatureExtractor?
    // 重用 CIContext（優先用 Metal）避免每幀建立花費
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

    /// 當 session 準備完成後，回傳
    var onSessionReady: ((AVCaptureSession) -> Void)?
    
    /// 當拍完照後的回傳 -> 回傳處理過的 embeeding
    var onPhotoReady: ((([Float], UIImage)) -> Void)?
    
//    •    你在 CameraController 裡面用了 AsyncStream<CMSampleBuffer> 來建立一個非同步的影格（frame）資料流。
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
            isRunning = false
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

    /// 觸發單張拍照（不破壞原本即時串流邏輯）
    /// - Parameters:
    ///   - flashMode: 閃光燈模式，預設 .auto
    ///   - highResolution: 是否要求高解析照片（若裝置支援）
    public func capturePhoto(flashMode: AVCaptureDevice.FlashMode = .auto,
                             highResolution: Bool = true) {
        sessionQueue.async { [weak self] in
            guard let self, let photoOutput = self.photoOutput else { return }

            let settings = AVCapturePhotoSettings()

            // 高解析度
            if highResolution {
                // 例如確認裝置支援的最大尺寸比預設大
                let maxDimensions = photoOutput.maxPhotoDimensions
                if maxDimensions.width > 1920 || maxDimensions.height > 1080 {
                    settings.maxPhotoDimensions = maxDimensions
                }
            }

            // 閃光燈（若支援）
            if photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
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
//
//    可以把 setupCaptureSession 想成「搭舞台」：
//        •    AVCaptureSession → 整個舞台。
//        •    AVCaptureDeviceInput → 麥克風（相機裝置），讓舞台有輸入。
//        •    AVCaptureVideoDataOutput → 音響喇叭（輸出），讓東西能傳出去。
//        •    canAddInput / canAddOutput → 檢查舞台是否能裝下這些設備。
//        •    delegate → 音控人員，持續監聽並把聲音（這裡是影像）丟給外部。
//
//    這樣一來，會比較容易理解為什麼每一步都必須設置。
    // 設定相機 session 的輸入與輸出，並處理權限、裝置選擇、輸入、輸出等流程
    func setupCaptureSession(position: AVCaptureDevice.Position) {
        guard let captureSession else { return }

        // 建立影像輸出物件
        let videoOutput = AVCaptureVideoDataOutput()

        // 指定像素格式，確保輸出為 32BGRA；也可讓後續 CI/CG 轉換更穩定
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // 丟棄延遲的影格，避免佇列堆積
        videoOutput.alwaysDiscardsLateVideoFrames = true

        // 若無權限則直接返回
        guard permissionGranted else {
            print("No permission for camera")
            return
        }

        // 搜尋指定位置（前/後鏡頭）可用的相機裝置
        let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: position)

        // 取得第一個可用裝置
        guard
            let videoDevice = videoDeviceDiscoverySession.devices.first
        else {
            print("Unable to find video device")
            return
        }
        // 建立裝置輸入
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Unable to create AVCaptureDeviceInput")
            return
        }
        // 檢查是否可加入輸入
        guard captureSession.canAddInput(videoDeviceInput) else {
            print("Unable to add input")
            return
        }
        // 將輸入加入 session
        captureSession.addInput(videoDeviceInput)

        // 設定影像輸出的 delegate 與處理隊列
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        captureSession.addOutput(videoOutput)
        // 設定畫質（解析度）
        captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480

        // 新增拍照輸出（不影響既有串流流程）
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }

        // 根據裝置類型決定方向設定
        if videoDevice.isContinuityCamera {
            setOrientation(.portrait)
        } else {
            setOrientation(UIDevice.current.orientation)
        }
    }
    // 僅在尚未啟動時才會真正啟動相機
    public func startIfNeeded() {
        if !isRunning {
            start()
        }
    }
}

// 擴充 CameraController 支援 AVCaptureVideoDataOutputSampleBufferDelegate
// 用於取得每一幀的相機畫面資料
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // 當有新影格輸出時會呼叫此方法
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if sampleBuffer.isValid, let pixelBuffer = sampleBuffer.imageBuffer {
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
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("拍照失敗: \(error)")
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let clip = clipExtractor else { return }
            if let embedding = clip.multiCropAverageEmbedding(for: image, cropScale: 0.85) {
                self.onPhotoReady?((embedding, image))
            }
        }
    }
}
