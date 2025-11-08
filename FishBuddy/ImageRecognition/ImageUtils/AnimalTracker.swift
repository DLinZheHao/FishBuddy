//
//  AnimalTracker.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/11/4.
//

import Vision
import CoreVideo

/// 使用 Apple Vision 的物件追蹤器。
/// - 功能重點：
///   - 接收初始的邊界框（Vision 規範的 normalized CGRect，座標原點在左下，範圍 0…1）
///   - 針對每一張新影格（CVPixelBuffer）進行追蹤更新
///   - 若追蹤失敗或信心值過低，會自動停止追蹤
///   - 透過 onUpdate 回呼傳回最新的邊界框（同為 Vision normalized rect）
final class AnimalTracker {

    /// VNSequenceRequestHandler 用於在一連串的影格上執行 Vision 請求，
    /// 可保留內部狀態以提升連續處理的效率。
    private let sequenceHandler = VNSequenceRequestHandler()

    /// 當前的追蹤請求。成功 startTracking 後會建立，失敗或遺失追蹤時會被設為 nil。
    private var trackingRequest: VNTrackObjectRequest?

    /// 開始追蹤。
    /// - Parameter initialBoundingBox: 初始偵測到的物件邊界框（Vision normalized，0…1，原點在左下）。
    /// - 說明：
    ///   - 以初始邊界框建立 VNDetectedObjectObservation
    ///   - 再用它建立 VNTrackObjectRequest
    ///   - trackingLevel 設為 .accurate 以提升準確度（可能稍微增加計算成本）
    func startTracking(initialBoundingBox: CGRect) {
        let observation = VNDetectedObjectObservation(boundingBox: initialBoundingBox)
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .accurate
        self.trackingRequest = request
    }

    /// 在新影格上更新追蹤狀態。
    /// - Parameter pixelBuffer: 來自相機或影片的影格資料。
    /// - 流程：
    ///   1. 確認目前有有效的 trackingRequest
    ///   2. 使用 sequenceHandler 在該影格上執行追蹤請求
    ///   3. 取出最新的觀測結果 VNDetectedObjectObservation
    ///   4. 若信心值過低（此處閾值為 0.3），則視為遺失追蹤並清空請求
    ///   5. 若成功，更新 request.inputObservation 以便下一幀延續追蹤
    ///   6. 透過 onUpdate 回呼傳出最新的 boundingBox（Vision normalized 座標系）
    func processFrame(pixelBuffer: CVPixelBuffer) {
        guard let request = trackingRequest else { return }

        do {
            // 在此影格上執行追蹤請求
            try sequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            // 若 Vision 執行失敗，停止追蹤
            print("Tracking failed: \(error)")
            trackingRequest = nil
            return
        }

        // 取出最新的觀測結果，並檢查信心值
        guard let newObs = request.results?.first as? VNDetectedObjectObservation,
              newObs.confidence > 0.3 else {
            print("Lost tracking")
            trackingRequest = nil
            return
        }

        // 更新輸入觀測以持續追蹤
        request.inputObservation = newObs

        // 回傳 Vision normalized 座標（0…1，原點在左下）
        onUpdate?(newObs.boundingBox)
    }

    /// 當追蹤更新時回呼最新的 Vision normalized boundingBox。
    /// - 注意：若要用於 UIKit 或 AVFoundation 的畫面座標，需做座標系轉換：
    ///   - Vision: 原點在左下，寬高為 0…1
    ///   - UIKit: 原點在左上，且需乘上實際像素或視圖大小
    var onUpdate: ((CGRect) -> Void)?
}
