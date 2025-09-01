//
//  JsonUtils.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/1.
//

import Foundation

class JsonUtils {
    static let sharedInstance = JsonUtils()
        
    /// 在 xcode 讀取 json 檔案
    func loadEmbeddingJSONFromBundle(fileName: String) throws -> EmbeddingImgModel {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw NSError(domain: "JsonUtils", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到檔案 \(fileName).json"])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(EmbeddingImgModel.self, from: data)
    }
}
