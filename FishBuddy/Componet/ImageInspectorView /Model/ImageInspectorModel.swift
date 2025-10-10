//
//  ImageInspectorModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/10.
//

import Foundation
import SwiftUI

// 圖片資料
struct ImageData: Identifiable {
    let id = UUID()
    var image: URL
    var description: String?
}

// 圖片檢視器狀態（用於 fullScreenCover）
struct ViewerState: Identifiable {
    let id = UUID()
    var index: Int
}
