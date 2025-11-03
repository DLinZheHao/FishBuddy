//
//  CachedTileOverlay.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/28.
//

import MapKit

/// 快取式圖層：優先用快取，無則抓網路；使用磁碟快取
class CachedTileOverlay: MKTileOverlay {
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.urlCache = TileCache.shared                // 你自訂的較大快取
        cfg.waitsForConnectivity = false               // 沒網路立即回錯，不掛起
        cfg.httpMaximumConnectionsPerHost = 6          // 合理並發
        return URLSession(configuration: cfg)
    }()

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        guard let tpl = urlTemplate else { result(nil, nil); return }
        let urlStr = tpl
            .replacingOccurrences(of: "{z}", with: String(path.z))
            .replacingOccurrences(of: "{x}", with: String(path.x))
            .replacingOccurrences(of: "{y}", with: String(path.y))
        guard let url = URL(string: urlStr) else { result(nil, nil); return }

        var req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        // 如果需要：req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: req) { data, _, err in
            result(data, err)
        }.resume()
    }
}

/// 只回應台灣區域的瓦片（可減少非必要請求）
final class TWBoundedCachedOverlay: CachedTileOverlay {
    override var boundingMapRect: MKMapRect { .taiwan }
}
