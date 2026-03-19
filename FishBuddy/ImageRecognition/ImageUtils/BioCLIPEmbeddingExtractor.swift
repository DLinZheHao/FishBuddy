//
//  BioCLIPEmbeddingExtractor.swift
//  CLIPPipeline
//
//  Created by 林哲豪 on 2026/2/15.
//

import CoreML
import UIKit

/// BioCLIP_iNat_Embed 專用：
/// - Input: `image_tensor` (Float32 MLMultiArray, shape [1,3,224,224])
/// - Output: `var_1227` (Float32 MLMultiArray, shape [1,512])
///
/// Note: 你的轉換版本已在模型內做過 L2 normalization（輸出向量 norm ≈ 1）。
final class BioCLIPEmbeddingExtractor {
    private let model: BioCLIP_iNat_Embed

    init() throws {
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .all
        self.model = try BioCLIP_iNat_Embed(configuration: cfg)
    }

    /// 取出 512 維 embedding。
    /// - Parameter tensor: 已完成 CLIP 前處理的 Float32 tensor (shape [1,3,224,224])
    func embedding(fromImageTensor tensor: MLMultiArray) throws -> [Float32] {
        let out = try model.prediction(image_tensor: tensor)
        return out.var_1227.toFloat32Array()
    }
}

private extension MLMultiArray {
    /// 將 MLMultiArray 轉成 [Float32]（支援 .float32 / .double / 其他以 NSNumber fallback）。
    func toFloat32Array() -> [Float32] {
        let n = self.count
        var out = [Float32](repeating: 0, count: n)

        switch self.dataType {
        case .float32:
            let p = self.dataPointer.bindMemory(to: Float32.self, capacity: n)
            out.withUnsafeMutableBufferPointer { dst in
                dst.baseAddress!.assign(from: p, count: n)
            }
        case .double:
            let p = self.dataPointer.bindMemory(to: Double.self, capacity: n)
            for i in 0..<n { out[i] = Float32(p[i]) }
        default:
            // Fallback：較慢但保險
            for i in 0..<n { out[i] = Float32(truncating: self[i]) }
        }

        return out
    }
}

/// BioCLIP 專用 extractor：
/// - 用法：`let ex = try BioCLIPFeatureExtractor(); ex.embedding(for: cgImage)`
/// - 內部會做：center-crop -> resize 224 -> CLIP mean/std normalize -> tensor -> CoreML prediction
final class BioCLIPFeatureExtractor {
    private let extractor: BioCLIPEmbeddingExtractor

    init() throws {
        self.extractor = try BioCLIPEmbeddingExtractor()
    }

    func embedding(for cg: CGImage) -> [Float32]? {
        guard let tensor = makeInputTensor(from: cg) else { return nil }
        return try? extractor.embedding(fromImageTensor: tensor)
    }
    
    /// 從 UIImage 取 embedding。若失敗回傳 nil。
    func embedding(for uiImage: UIImage) -> [Float32]? {
        guard let cg = uiImage.cgImage else { return nil }
        return embedding(for: cg)
    }

    private func makeInputTensor(from cg: CGImage) -> MLMultiArray? {
        let w = cg.width
        let h = cg.height
        let side = min(w, h)
        let ox = (w - side) / 2
        let oy = (h - side) / 2
        let cropRect = CGRect(x: ox, y: oy, width: side, height: side)
        guard let cropped = cg.cropping(to: cropRect) else { return nil }

        let target = 224
        let bytesPerRow = target * 4
        // RGBA 8-bit buffer for a single 224x224 image
        var rgba = [UInt8](repeating: 0, count: target * bytesPerRow)

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rgba,
            width: target,
            height: target,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: target, height: target))

        // CLIP normalization constants (OpenCLIP / OpenAI CLIP)
        let mean: [Float32] = [0.48145466, 0.4578275, 0.40821073]
        let std:  [Float32] = [0.26862954, 0.26130258, 0.27577711]

        guard let arr = try? MLMultiArray(shape: [1, 3, 224, 224], dataType: .float32) else { return nil }

        // Fast path: write Float32 values directly into MLMultiArray memory.
        // Layout is assumed contiguous in row-major order for the given shape.
        let n = arr.count // 1*3*224*224
        let p = arr.dataPointer.bindMemory(to: Float32.self, capacity: n)

        // CHW index helper: ((c * H) + y) * W + x, since batch=1
        @inline(__always)
        func idx(_ c: Int, _ y: Int, _ x: Int) -> Int {
            return (c * 224 + y) * 224 + x
        }

        for y in 0..<224 {
            let rowBase = y * bytesPerRow
            for x in 0..<224 {
                let i = rowBase + x * 4

                // RGBA (premultipliedLast): [R,G,B,A]
                let r = Float32(rgba[i + 0]) * (1.0 / 255.0)
                let g = Float32(rgba[i + 1]) * (1.0 / 255.0)
                let b = Float32(rgba[i + 2]) * (1.0 / 255.0)

                // CLIP normalize
                p[idx(0, y, x)] = (r - mean[0]) / std[0]
                p[idx(1, y, x)] = (g - mean[1]) / std[1]
                p[idx(2, y, x)] = (b - mean[2]) / std[2]
            }
        }

        return arr
    }
}

func cosine(_ a: [Float32], _ b: [Float32]) -> Float32 {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var dot: Float32 = 0
    var na: Float32 = 0
    var nb: Float32 = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        na += a[i] * a[i]
        nb += b[i] * b[i]
    }
    return dot / (sqrt(na) * sqrt(nb) + 1e-12)
}
