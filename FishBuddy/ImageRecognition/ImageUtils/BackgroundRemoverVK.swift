//
//  BackgroundRemoverVK.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/18.
//  Updated by ChatGPT on 2025/9/18: +ROI / Multi-scale / Post-process / Quality gate / Fallback
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

@MainActor
final class BackgroundRemoverVK {

    // MARK: - Configuration

    struct Options {
        /// 若提供 ROI，會先將影像裁到該區域再做分割（以「原圖座標系」為準）
        var roi: CGRect? = nil

        /// 是否使用多尺度（原尺寸 + 短邊縮放到 targetShortSide），並合併遮罩
        var enableMultiScale: Bool = true
        var targetShortSide: CGFloat = 1024

        /// 只取最大的前景實例（避免把小雜物也分割進來）
        var useBiggestInstanceOnly: Bool = false

        /// 後處理參數：二值化門檻、形態學 kernel（像素）、羽化半徑
        var binarizeThreshold: CGFloat = 0.50
        var morphologyKernel: Int = 3          // 3 或 5 常用
        var featherRadius: CGFloat = 1.2       // 0.8 ~ 2.0

        /// 品質門檻：前景比例低於此值 → 視為失敗（回退）
        var minForegroundRatio: CGFloat = 0.05

        /// 回退策略：當品質不佳時是否直接回傳原圖
        var fallbackReturnOriginalOnLowQuality: Bool = true
    }

    private let ciContext = CIContext(options: nil)

    // MARK: - Public API

    /// 將主體抠出，輸出具備透明通道的 UIImage（PNG）
    /// - Parameters:
    ///   - uiImage: 輸入原圖
    ///   - options: 參數（ROI/多尺度/後處理/品質門檻…）
    func removeBackground(from uiImage: UIImage, options: Options = Options()) async throws -> UIImage {
        guard let cgInput = uiImage.cgImage else {
            throw NSError(domain: "vk.image", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法取得 CGImage"])
        }

        // 建立 CIImage 方便做 ROI/縮放
        let inputCI = CIImage(cgImage: cgInput)

        // 1) ROI 裁切（如有）
        let workingCI: CIImage
        if let roi = options.roi {
            let cropRect = inputCI.extent.intersection(roi)
            workingCI = inputCI.cropped(to: cropRect)
        } else {
            workingCI = inputCI
        }

        // 2) 取得「原尺度」遮罩
        guard let cgWorking = makeCG(workingCI) else {
            throw NSError(domain: "vk.ci", code: -10, userInfo: [NSLocalizedDescriptionKey: "CG 轉換失敗（原尺度）"])
        }
        let mask1 = try runVNMask(cgImage: cgWorking,
                                  orientation: .up, // 經過 CI 處理後用 .up 最穩定
                                  useBiggestInstanceOnly: options.useBiggestInstanceOnly)

        // 3) 多尺度：縮放到 targetShortSide 再跑一次，最後合併（取最大值）
        let mergedMaskCI: CIImage = {
            guard options.enableMultiScale else {
                return CIImage(cvPixelBuffer: mask1)
            }
            let resized = resizeCI(workingCI, targetShortSide: options.targetShortSide)
            guard let cgResized = makeCG(resized) else {
                return CIImage(cvPixelBuffer: mask1)
            }
            let mask2 = try? runVNMask(cgImage: cgResized,
                                       orientation: .up,
                                       useBiggestInstanceOnly: options.useBiggestInstanceOnly)

            // 若第二張失敗，就用第一張
            guard let mask2 = mask2 else {
                return CIImage(cvPixelBuffer: mask1)
            }

            // 將 mask2 放大回 workingCI 尺寸後，與 mask1 取最大（union）
            let m1 = CIImage(cvPixelBuffer: mask1)
            let m2Small = CIImage(cvPixelBuffer: mask2)
            let m2 = m2Small.transformed(toFit: workingCI.extent.size)

            // 最大值合成（類似 OR）：CIMaximumCompositing
            return m2.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: m1])
        }()

        // 4) 遮罩後處理（二值化 + 形態學閉運算 + 羽化）
        let refinedMask = postprocessMask(mergedMaskCI,
                                          binarizeThreshold: options.binarizeThreshold,
                                          morphologyKernel: options.morphologyKernel,
                                          featherRadius: options.featherRadius)
            .cropped(to: workingCI.extent)

        // 5) 品質檢查（以二值化後的平均值當作前景比例）
        let fgRatio = foregroundRatio(from: refinedMask)
        if fgRatio < options.minForegroundRatio {
            if options.fallbackReturnOriginalOnLowQuality {
                // 回傳原圖（保持與輸入相同的 scale/方向）
                return uiImage
            } else {
                throw NSError(domain: "vk.quality", code: -20, userInfo: [NSLocalizedDescriptionKey: "前景比例過低：\(fgRatio)"])
            }
        }

        // 6) 合成透明背景輸出
        let transparentBG = CIImage(color: .clear).cropped(to: workingCI.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = workingCI
        blend.backgroundImage = transparentBG
        blend.maskImage = refinedMask
        guard let outputCI = blend.outputImage else {
            throw NSError(domain: "vk.ci", code: -3, userInfo: [NSLocalizedDescriptionKey: "CoreImage 合成失敗（blend output 為空）"])
        }

        // 若有 ROI，需把結果貼回原圖尺寸；若沒有，直接輸出
        let finalCI: CIImage
        if let roi = options.roi {
            // 先建立一張全透明底的原圖大小畫布
            let canvas = CIImage(color: .clear).cropped(to: inputCI.extent)
            // 將 workingCI（ROI 區域）的位置貼回對應座標
            let translated = outputCI.translated(to: roi.origin)
            finalCI = translated.composited(over: canvas)
        } else {
            finalCI = outputCI
        }

        guard let outCG = ciContext.createCGImage(finalCI, from: finalCI.extent) else {
            throw NSError(domain: "vk.ci", code: -2, userInfo: [NSLocalizedDescriptionKey: "CoreImage 合成失敗（createCGImage 失敗）"])
        }

        return UIImage(cgImage: outCG, scale: uiImage.scale, orientation: uiImage.imageOrientation)
    }

    // MARK: - Vision mask

    /// 跑 VN 前景實例分割，回傳單通道的 CVPixelBuffer 遮罩
    private func runVNMask(cgImage: CGImage,
                           orientation: CGImagePropertyOrientation,
                           useBiggestInstanceOnly: Bool) throws -> CVPixelBuffer {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw NSError(domain: "vk.mask", code: 404, userInfo: [NSLocalizedDescriptionKey: "未偵測到可分割之前景"])
        }

        // Vision uses IndexSet (of instance indices), not typed Instance objects.
        let all = result.allInstances

        let instancesToUse: IndexSet
        if useBiggestInstanceOnly, !all.isEmpty {
            var bestIndex: Int?
            var bestScore: CGFloat = -1

            for idx in all {
                // Build a mask for this single instance to estimate its area quickly.
                let singleMask = try result.generateScaledMaskForImage(forInstances: IndexSet(integer: idx),
                                                                       from: handler)
                let score = foregroundRatio(from: singleMask) // 0..1
                if score > bestScore {
                    bestScore = score
                    bestIndex = idx
                }
            }

            if let idx = bestIndex {
                instancesToUse = IndexSet(integer: idx)
            } else {
                instancesToUse = all
            }
        } else {
            instancesToUse = all
        }

        return try result.generateScaledMaskForImage(forInstances: instancesToUse, from: handler)
    }

    // MARK: - Mask post-process

    /// 二值化 + 形態學閉運算 + 羽化
    private func postprocessMask(_ mask: CIImage,
                                 binarizeThreshold t: CGFloat,
                                 morphologyKernel k: Int,
                                 featherRadius fr: CGFloat) -> CIImage {
        // 1) 二值化：將灰階值以門檻 t 切分為 0/1
        // 使用 CIColorMatrix 的 alpha 通道 trick 逼近 step()；在灰階遮罩上效果近似。
        let bin = mask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 10), // 放大對比
            "inputBiasVector": CIVector(x: -10*t, y: -10*t, z: -10*t, w: -10*t)
        ])

        // 2) 形態學閉運算：先膨脹再侵蝕，補洞、連接破碎邊緣
        let kernel = max(1, k)
        let dilated  = bin.applyingFilter("CIMorphologyRectangleMaximum",
                                          parameters: ["inputWidth": kernel, "inputHeight": kernel])
        let closed   = dilated.applyingFilter("CIMorphologyRectangleMinimum",
                                              parameters: ["inputWidth": kernel, "inputHeight": kernel])

        // 3) 輕微羽化：避免鋸齒
        let feather = closed.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: fr])

        return feather
    }

    // MARK: - Quality metric

    /// 估算前景比例（使用二值化後遮罩的平均值）
    private func foregroundRatio(from mask: CIImage) -> CGFloat {
        // Compute 1×1 average color of the (grayscale) mask
        let avg = mask.applyingFilter("CIAreaAverage",
                                      parameters: [kCIInputExtentKey: CIVector(cgRect: mask.extent)])

        var pixel = [UInt8](repeating: 0, count: 4) // RGBA8
        let cs = CGColorSpaceCreateDeviceRGB()
        ciContext.render(avg,
                         toBitmap: &pixel,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: cs)

        // For grayscale mask, R≈G≈B. Use red channel as intensity [0,1].
        let r = CGFloat(pixel[0]) / 255.0
        return r.clamped(to: 0...1)
    }

    /// 估算前景比例（CVPixelBuffer 版本）
    private func foregroundRatio(from pixelBuffer: CVPixelBuffer) -> CGFloat {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        return foregroundRatio(from: ci)
    }

    // MARK: - Helpers (CI <-> CG, Resize, Transforms)

    private func makeCG(_ ci: CIImage) -> CGImage? {
        return ciContext.createCGImage(ci, from: ci.extent)
    }

    /// 將 CIImage 按短邊縮放到 targetShortSide
    private func resizeCI(_ ci: CIImage, targetShortSide: CGFloat) -> CIImage {
        let w = ci.extent.width
        let h = ci.extent.height
        let short = min(w, h)
        guard short > 0 else { return ci }
        let scale = targetShortSide / short
        if abs(scale - 1) < 0.01 { return ci }

        return ci.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1.0
        ])
    }

    /// 將影像放大/縮小以「貼合」指定尺寸（保持比例，置中貼齊）
    private func transformedToFit(_ ci: CIImage, size: CGSize) -> CIImage {
        let src = ci.extent.size
        let sx = size.width / src.width
        let sy = size.height / src.height
        return ci.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
    }
}

private extension CIImage {
    /// 以置中方式將自身縮放到指定尺寸（不裁切，僅縮放）
    func transformed(toFit size: CGSize) -> CIImage {
        let src = extent.size
        let sx = size.width / src.width
        let sy = size.height / src.height
        return transformed(by: CGAffineTransform(scaleX: sx, y: sy))
    }

    /// 平移到指定座標
    func translated(to origin: CGPoint) -> CIImage {
        return transformed(by: CGAffineTransform(translationX: origin.x - extent.origin.x,
                                                 y: origin.y - extent.origin.y))
    }
}

// 小工具：把 UIImage.Orientation 轉成 Vision 需要的 CGImagePropertyOrientation
private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
