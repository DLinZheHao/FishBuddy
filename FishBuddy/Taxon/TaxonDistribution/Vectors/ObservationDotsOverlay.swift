//
//  ObservationDotsOverlay.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/28.
//

import MapKit

final class ObservationDotsOverlay: NSObject, MKOverlay {
    /// 覆蓋層的中心座標（提供給地圖引擎定位與索引用）
    let coordinate: CLLocationCoordinate2D
    /// 覆蓋層涵蓋的邊界矩形（告訴地圖這個覆蓋層的空間範圍）
    let boundingMapRect: MKMapRect
    /// 要繪製的觀測點集合（以 MKMapPoint 表示，便於投影與像素轉換）
    let points: [MKMapPoint]

    /// 以一組 MKMapPoint 建立可繪製的點狀覆蓋層：計算外接矩形與中心座標
    init(points: [MKMapPoint]) {
        // 將傳入的地圖點集合保存起來（後續 renderer 會用它來畫圓點）
        self.points = points

        if let first = points.first {
            // 以第一個點建立「零大小」矩形，做為外接矩形的初始值
            var rect = MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))

            // 走訪其餘點，將每個點用 union 擴張到外接矩形中
            for p in points.dropFirst() {
                rect = rect.union(MKMapRect(origin: p, size: MKMapSize(width: 0, height: 0)))
            }

            // 設定覆蓋層的空間範圍＝所有點的外接矩形
            self.boundingMapRect = rect

            // 設定覆蓋層中心：若 rect 合法則取中心座標，否則退回 (0,0)
            self.coordinate = rect.isNull ? .init(latitude: 0, longitude: 0) : rect.centerCoordinate
        } else {
            // 沒有任何點：覆蓋層範圍設為整個世界座標，中心設為 (0,0)
            self.boundingMapRect = .world
            self.coordinate = .init(latitude: 0, longitude: 0)
        }

        // 最後呼叫父類別初始化
        super.init()
    }
}
