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
    var id: String { city }
    /// 城市名稱
    @Default var city: String
    /// 城市天氣資料
    @Default var weather: [WeatherInfo]
}

struct WeatherInfo: Codable, Identifiable {
    /// 唯一識別碼
    var id: String { startTime + endTime }
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
}
