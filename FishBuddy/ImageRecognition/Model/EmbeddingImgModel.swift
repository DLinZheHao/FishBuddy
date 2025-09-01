//
//  EmbeddingImgModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/1.
//

struct EmbeddingImgModel: Codable {
    /// 圖片名稱
    @Default var id: String
    /// 圖片向量
    @Default var vector: [Float]
}
