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


struct SearchResult {
    let id: String
    let score: Float
}

actor EmbeddingStore {
    static let shared = EmbeddingStore()
    private var cache: [EmbeddingImgModel]?

    func database() async throws -> [EmbeddingImgModel] {
        if let cache { return cache }
        let db = try JsonUtils.sharedInstance.loadEmbeddingJSONFromBundle(fileName: "embeddings_test_Img")
        cache = db
        return db
    }
}
