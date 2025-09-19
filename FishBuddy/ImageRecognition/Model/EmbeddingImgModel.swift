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

/// 完整對應 JSON `items[]` 的資料結構（保持原樣 + 可選 embedding 欄位）
struct TaxonItem: Codable {
    // 從 iNaturalist + Wiki 抓下來的資料
    @Default var taxonId: Int
    let scientificName: String?
    let commonName: String?
    let slug: String?
    let photos: [Photo]?
    let meta: Meta?
    // 預先處理的圖片向量資料
    @Default var embedding: [Float]
    // 預處理的文字向量資料
    @Default var textEmbedding: [Float]
    
    let embeddingMeta: EmbeddingMeta?

    enum CodingKeys: String, CodingKey {
        case taxonId = "taxon_id"
        case scientificName = "scientific_name"
        case commonName = "common_name"
        case slug
        case photos
        case meta
        case embedding
        case embeddingMeta = "embedding_meta"
        case textEmbedding = "text_embedding"
    }
}

struct Photo: Codable {
    @Default var url: String
    let licenseCode: String?
    let attribution: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case url
        case licenseCode = "license_code"
        case attribution
        case source
    }
}

struct Meta: Codable {
    let wikipedia: WikipediaMeta?
}

struct WikipediaMeta: Codable {
    let title: String?
    let canonicalTitle: String?
    let extract: String?
    let url: String?
    let lang: String?
    let variant: String?
    let query: String?
    let strategy: String?
    let sections: Sections?

    enum CodingKeys: String, CodingKey {
        case title
        case canonicalTitle = "canonical_title"
        case extract
        case url
        case lang
        case variant
        case query
        case strategy
        case sections
    }
}

struct Sections: Codable {
    let distribution: String?
    let description: String?
    let ecology: String?
    let economicUse: String?

    enum CodingKeys: String, CodingKey {
        case distribution
        case description
        case ecology
        case economicUse = "economic_use"
    }
}

/// 寫入到 JSON 的 meta 摘要（保持你目前 embedIntoJSON 的鍵名）
struct EmbeddingMeta: Codable {
    @Default var model: String
    @Default var method: String
    @Default var cropScale: Double
    @Default var photosTotal: Int
    @Default var photosUsed: Int
    @Default var removed: Int
    @Default var dim: Int

    enum CodingKeys: String, CodingKey {
        case model
        case method
        case cropScale
        case photosTotal = "photos_total"
        case photosUsed = "photos_used"
        case removed
        case dim
    }
}


/// 搜尋結果
struct SearchResult {
    let id: String
    let score: Float
}

