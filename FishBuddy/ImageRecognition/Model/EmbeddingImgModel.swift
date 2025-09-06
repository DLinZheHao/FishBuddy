//
//  EmbeddingImgModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/1.
//


/// database 裡的資料
struct EmbeddingImgModel: Codable {
    /// 圖片標號
    @Default var id: String
    /// 圖片名稱
    @Default var name: String
    /// 圖片向量
    @Default var vector: [Float32]
}

/// 搜尋結果
struct SearchResult {
    let id: String
    let score: Float
}

