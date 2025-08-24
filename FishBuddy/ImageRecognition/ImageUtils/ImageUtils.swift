//
//  ImageUtils.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/8/24.
//

import Foundation
import UIKit

extension UIImage {
    /// 將圖片縮小到 8×8，取平均顏色 (RGB)，結果落在 0–1
    func averageRGBFeature() -> [CGFloat]? {
        // 定義縮小後的圖片尺寸為 8x8
        let size = CGSize(width: 8, height: 8)
        
        // 建立一個 UIGraphicsImageRenderer，準備繪製新的縮小圖片
        let renderer = UIGraphicsImageRenderer(size: size)
        // 使用 renderer 繪製縮小後的圖片
        let resized = renderer.image { _ in
            // 將原圖繪製到指定大小的矩形中，完成縮小
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        
        // 取得縮小後圖片的 CGImage，並取得像素資料指標
        guard let cgImage = resized.cgImage,
              let data = cgImage.dataProvider?.data,
              // ptr 是 UnsafePointer<UInt8>，指向圖片像素資料的指標。
              // 每個像素由 4 個 byte (R,G,B,A) 組成。
              // 可透過 offset 計算存取正確的像素位置。
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        // 取得圖片寬度（像素數）
        let width = cgImage.width
        // 取得圖片高度（像素數）
        let height = cgImage.height
        // 每個像素佔用 4 個位元組（bytes），分別儲存 R（紅）、G（綠）、B（藍）、A（透明度）四個通道。
        // 每個通道各佔 1 byte（範圍 0–255），所以總共 4 bytes。
        // 計算 offset 時會根據這個數字跳到正確的像素資料位置。
        let bytesPerPixel = 4
        
        // 用來累加所有像素的紅、綠、藍色值
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        
        // 逐像素遍歷圖片的每個像素，計算總 RGB 值
//        假設圖片是 8×8，bytesPerPixel=4：
//            •    像素 (0,0) → (0*8+0)*4=0 → 從第 0 個 byte 開始（第一個像素）。
//            •    像素 (1,0) → (0*8+1)*4=4 → 從第 4 個 byte 開始（第二個像素）。
//            •    像素 (0,1) → (1*8+0)*4=32 → 第二列的第一個像素（第 9 個像素）。
        for y in 0..<height {
            for x in 0..<width {
                // 計算此像素在資料陣列中的起始位移 (offset)
                let offset = (y * width + x) * bytesPerPixel
                // 讀取紅色通道值，並正規化到 0~1 範圍
                let r = CGFloat(ptr[offset])   / 255.0
                // 讀取綠色通道值，並正規化到 0~1 範圍
                let g = CGFloat(ptr[offset+1]) / 255.0
                // 讀取藍色通道值，並正規化到 0~1 範圍
                let b = CGFloat(ptr[offset+2]) / 255.0
                
                // 累加各通道值
                totalR += r
                totalG += g
                totalB += b
            }
        }
        
        // 計算總像素數量
        let count = CGFloat(width * height)
        // 計算平均 RGB 值，並以陣列形式回傳
        return [totalR/count, totalG/count, totalB/count]
    }
}
