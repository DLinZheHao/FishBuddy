//
//  MKMapRectExtension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/28.
//

import MapKit

public extension MKMapRect {
    /// 範圍設置台灣
    static var taiwan: MKMapRect {
        let sw = MKMapPoint(CLLocationCoordinate2D(latitude: 21.8, longitude: 119.3))
        let ne = MKMapPoint(CLLocationCoordinate2D(latitude: 25.4, longitude: 122.1))
        return MKMapRect(x: min(sw.x, ne.x), y: min(sw.y, ne.y),
                         width: abs(ne.x - sw.x), height: abs(ne.y - sw.y))
    }
}

public extension MKMapRect {
    /// 返回中央座標
    var centerCoordinate: CLLocationCoordinate2D {
        let center = MKMapPoint(x: midX, y: midY)
        return center.coordinate
    }
}
