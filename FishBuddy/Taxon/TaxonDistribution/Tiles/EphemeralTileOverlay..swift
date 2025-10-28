//
//  EphemeralTileOverlay..swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/28.
//

import MapKit

/// 臨時性圖層：只使用記憶體，不佔用磁碟；適合點狀資料
class EphemeralTileOverlay: MKTileOverlay {
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        guard let tpl = urlTemplate else { result(nil, nil); return }
        let urlStr = tpl
            .replacingOccurrences(of: "{z}", with: String(path.z))
            .replacingOccurrences(of: "{x}", with: String(path.x))
            .replacingOccurrences(of: "{y}", with: String(path.y))
        guard let url = URL(string: urlStr) else { result(nil, nil); return }
        session.dataTask(with: URLRequest(url: url)) { data, _, err in
            result(data, err)
        }.resume()
    }
}

/// 只回應台灣區域的瓦片（可減少非必要請求）
final class TWBoundedEphemeralOverlay: EphemeralTileOverlay {
    override var boundingMapRect: MKMapRect { .taiwan }
}
