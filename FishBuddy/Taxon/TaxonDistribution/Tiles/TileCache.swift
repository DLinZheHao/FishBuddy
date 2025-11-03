//
//  TileCache.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/28.
//

import Foundation

/// Tile cache（所有物種地圖共用、小而固定）
enum TileCache {
    static let shared: URLCache = {
        URLCache(memoryCapacity: 32 * 1024 * 1024,  // 32MB RAM
                 diskCapacity: 120 * 1024 * 1024,   // 120MB for ALL species
                 diskPath: "inat-tiles-shared")
    }()
}
