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
        // 1) 拿到 CGImage
        guard let cg = uiImage.cgImage else { return nil }

        // 2) 從模型描述找出第一個 Image 輸入（不綁定名稱）
        let md = coreMLModel.modelDescription
        guard let (inputName, constraint) = md.inputDescriptionsByName.first(where: { _, desc in
            desc.imageConstraint != nil
        }).map({ ($0.key, $0.value.imageConstraint!) }) else {
            // 這個模型沒有 Image 輸入（可能是 MultiArray 輸入）。此時你就得自己做前處理再組 MultiArray。
            return nil
        }

        // 3) 讓 Core ML 依 constraint 自動把 CGImage → FeatureValue（含 resize/像素格式）
        // crop/scale 策略請依你的訓練前處理調整：.scaleFill / .scaleFit / .centerCrop
        let fv = try? MLFeatureValue(
            cgImage: cg,
            constraint: constraint,
            options: [.cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue]
        )
        guard let featureValue = fv else { return nil }

        // 4) 組成特徵提供者並做 prediction
        let provider = try? MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])
        guard let fp = provider, let out = try? coreMLModel.prediction(from: fp) else { return nil }

        // 5) 取出第一個 MultiArray 輸出（大多數 CLIP 影像編碼器會輸出一個向量）
        guard let embeddingArray = out.featureNames
            .compactMap({ out.featureValue(for: $0)?.multiArrayValue })
            .first else { return nil }

        // 6) 轉成 [Float] 並做 L2 normalize（cosine 相似度會比較穩定）
        let floats = embeddingArray.toFloatArray()
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
