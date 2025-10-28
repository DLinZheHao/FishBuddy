//
//  ObservationDotsRenderer..swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/28.
//

import MapKit
import UIKit

/// 專責將 `ObservationDotsOverlay` 中的點資料繪製到地圖上的 Renderer。
/// - 使用 Core Graphics 在 `MKOverlayPathRenderer` 的座標系中畫出小圓點。
/// - 透過 `zoomScale` 動態調整半徑，確保在不同縮放級別下圓點的「螢幕大小」一致。
final class ObservationDotsRenderer: MKOverlayPathRenderer {
    /// 圓點在螢幕上的目標半徑（以 pt 為單位）；會除以 `zoomScale` 以維持視覺大小恆定
    var dotRadius: CGFloat = 3.0
    /// 圓點填色（含透明度）
    var dotFillColor: UIColor = UIColor.systemRed.withAlphaComponent(0.85)

    /// 本類別直接在 `draw` 中動態產生路徑，因此這裡不預先建 path
    override func createPath() { /* path built in draw */ }

    /// 繪製可視區域內的觀測點
    /// - Parameters:
    ///   - mapRect: 目前地圖要重繪的範圍（地理座標空間，非螢幕座標）
    ///   - zoomScale: 目前縮放比例；數值越大代表越放大
    ///   - context: Core Graphics 繪圖上下文
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // 只處理我們的點狀覆蓋層
        guard let overlay = overlay as? ObservationDotsOverlay else { return }

        // 根據縮放比例換算實際繪製半徑：越放大時 zoomScale 越大，半徑要除以它才能保持螢幕視覺大小固定
        let r = dotRadius / zoomScale
        context.setFillColor(dotFillColor.cgColor)

        // 將每一個 MKMapPoint 轉成當前 renderer 的畫面座標，並以該點為中心畫圓
        for mp in overlay.points {
            let pt = point(for: mp) // 轉換到畫布座標（像素/點）
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            context.fillEllipse(in: rect)
        }
    }
}
