//
//  CLIPFeatureExtractor.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/8/30.
//

import CoreML
import Vision
import UIKit

/// 通用的 CLIP 影像編碼器封裝：
/// 1) 讀取模型的 imageConstraint，自動把 CGImage 轉成正確的輸入
/// 2) 不依賴特定自動生成的 Input/Output 名稱（動態找第一個 Image 輸入、第一個 MultiArray 輸出）
/// 3) 回傳 L2-normalized 的 [Float]
final class CLIPFeatureExtractor {
    /// 你的自動產生類別（請確保專案裡存在）。
    /// 我們只取出裡面的 `MLModel` 來用，避免卡在固定的 Input 型別。
    private let coreMLModel: MLModel

    init() {
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .all // .cpuOnly / .cpuAndGPU / .all（含 Neural Engine）
        // ↓ 這個類名要對應到你專案裡由 .mlmodel 產生的 Swift 類別（例如：mobileclip_s1_image）
        let wrapped = try! mobileclip_s1_image(configuration: cfg)
        self.coreMLModel = wrapped.model
    }

    /// 從 UIImage 取 embedding。若失敗回傳 nil。
    func embedding(for uiImage: UIImage) -> [Float]? {
        guard let cg = uiImage.cgImage else { return nil }
        return embedding(fromCGImage: cg)
    }

    /// 對單張圖片做多視窗裁切（five-crop）後各自取 embedding，最後做平均並 L2 正規化。
    /// - 視窗位置：center / left / right / top / bottom，視窗邊長為短邊的 `cropScale` 倍（預設 0.85）。
    /// - 輸入：UIImage；輸出：L2-normalized [Float]
    func multiCropAverageEmbedding(for uiImage: UIImage, cropScale: CGFloat = 0.85) -> [Float]? {
        guard let cg = uiImage.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let shortSide = CGFloat(min(w, h))
        let cropSize = max(1, min(shortSide, shortSide * cropScale))

        // 計算 5 個方形視窗（確保不超界）
        func rect(_ x: CGFloat, _ y: CGFloat) -> CGRect {
            let ox = max(0, min(CGFloat(w) - cropSize, x))
            let oy = max(0, min(CGFloat(h) - cropSize, y))
            return CGRect(x: ox, y: oy, width: cropSize, height: cropSize)
        }
        let cx = (CGFloat(w) - cropSize) / 2
        let cy = (CGFloat(h) - cropSize) / 2
        let rects = [
            rect(cx, cy),                  // center
            rect(0, cy),                   // left
            rect(CGFloat(w) - cropSize, cy), // right
            rect(cx, 0),                   // top
            rect(cx, CGFloat(h) - cropSize)  // bottom
        ]

        var acc: [Float] = []
        var count: Int = 0
        for r in rects {
            if let sub = cg.cropping(to: r) {
                // 重用下方的 embedding 流程：仍採用 centerCrop 以符合模型前處理
                if let vec = embedding(fromCGImage: sub) {
                    if acc.isEmpty { acc = vec } else {
                        // element-wise 加總
                        vDSP_vadd(acc, 1, vec, 1, &acc, 1, vDSP_Length(acc.count))
                    }
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        // 取平均
        var inv = 1.0 / Float(count)
        vDSP_vsmul(acc, 1, &inv, &acc, 1, vDSP_Length(acc.count))
        // 再做 L2 normalize
        let norm = sqrt(acc.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? acc.map { $0 / norm } : acc
    }

    /// 以 CGImage 作為輸入跑一次模型，回傳 L2-normalized 向量
    private func embedding(fromCGImage cg: CGImage) -> [Float]? {
        let md = coreMLModel.modelDescription
        // 動態尋找第一個影像輸入的名稱與限制條件
        guard let (inputName, constraint) = md.inputDescriptionsByName.first(where: { _, desc in
            desc.imageConstraint != nil
        }).map({ ($0.key, $0.value.imageConstraint!) }) else {
            return nil
        }
        // 將 CGImage 根據模型輸入的限制與預處理選項轉換成 MLFeatureValue
        let fv = try? MLFeatureValue(
            cgImage: cg,
            constraint: constraint,
            options: [.cropAndScale: VNImageCropAndScaleOption.centerCrop.rawValue]
        )
        guard let featureValue = fv else { return nil }
        // 將輸入包裝成 MLFeatureProvider 以供 CoreML 預測使用
        let provider = try? MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])
        guard let fp = provider, let out = try? coreMLModel.prediction(from: fp) else { return nil }
        // 執行模型預測，取得輸出
        // 動態選取第一個 MultiArray 輸出
        guard let embeddingArray = out.featureNames
            .compactMap({ out.featureValue(for: $0)?.multiArrayValue })
            .first else { return nil }
        // 將 MLMultiArray 轉換成 [Float]
        let floats = embeddingArray.toFloatArray()
        // 計算 L2 範數並正規化向量
        let norm = sqrt(floats.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? floats.map { $0 / norm } : floats
    }
}

// MARK: - Utilities
import Accelerate
private extension MLMultiArray {
    func toFloatArray() -> [Float] {
        switch dataType {
        case .float32:
            let count = self.count
            let ptr = self.dataPointer.bindMemory(to: Float.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: ptr, count: count)
            return Array(buffer)
        case .float64:
            let count = self.count
            let dptr = self.dataPointer.bindMemory(to: Double.self, capacity: count)
            let dbuf = UnsafeBufferPointer(start: dptr, count: count)
            var out = [Float](repeating: 0, count: count)
            vDSP_vdpsp(dbuf.baseAddress!, 1, &out, 1, vDSP_Length(count))
            return out
        default:
            // 其他型別不常見，保險起見做個通用拷貝
            return (0..<count).map { i in Float(truncating: self[i]) }
        }
    }
}
