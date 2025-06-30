//
//  WeatherAllModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/6.
//

import Foundation

struct WeatherResponse: Codable {
    @Default var data: [CityWeather]
}

struct CityWeather: Codable, Identifiable {
    /// 唯一識別碼
    let uuid = UUID()
    var id: UUID { uuid }
    /// 城市名稱
    @Default var city: String
    /// 城市天氣資料
    @Default var weather: [WeatherInfo]
    
    enum CodingKeys: String, CodingKey {
        case city, weather
    }
}

struct WeatherInfo: Codable, Identifiable {
    /// 唯一識別碼
    let uuid = UUID()
    var id: UUID { uuid }
    /// 起始時間
    @Default var startTime: String
    /// 結束時間
    @Default var endTime: String
    /// 天氣狀態
    @Default var description: String
    /// 最低氣溫
    @Default var minTemp: String
    /// 最高氣溫
    @Default var maxTemp: String
    /// 舒適度
    @Default var comfort: String
    
    enum CodingKeys: String, CodingKey {
        case startTime = "startTime"
        case endTime = "endTime"
        case description = "description"
        case minTemp = "minTemp"
        case maxTemp = "maxTemp"
        case comfort = "comfort"
    }
}


// MARK: - SwiftUI 重用機制說明
//
// 1. ⚠️ 不要把 UIKit 的 dequeue cell 機制套用到 SwiftUI。
//    - UIKit 是命令式（imperative），會重用記憶體中的實體（如 UITableViewCell）。
//    - SwiftUI 是宣告式（declarative）基於值類型和 diffing，所有 View 是 struct，沒有 dequeue 的概念。
//
// 2. ✅ SwiftUI 的重用依賴於 "id" 與資料內容。
//    - 系統會根據 id（例如 ForEach 的 id: \.id）判斷這是不是同一筆資料。
//    - 如果 id 沒變、資料沒變，SwiftUI 就會嘗試重用並避免重建 View。
//
// 3. 🧠 想要避免滑出去再滑進來時重建畫面，必須確保：
//    - 你的 id 是穩定的（例如資料模型中的固定主鍵）。
//
// 4. ❌ 若每次資料來源都不同，SwiftUI 無法進行 diff 比對，只能完全重建所有 View。
