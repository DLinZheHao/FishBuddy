//
//  TideDataModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/3/25.
//
// 開發日誌：目前物件可以使用 UIKit 就好，整包的物件要在 swiftUI 使用的話，開整個物件 @Published 就好

import Foundation
import SwiftUI

struct TideDataModel: Codable {
    @Default var TideData: [[Location]]
}

extension TideDataModel {
    /// 地點資料
    struct Location: Codable {
        /// 地點名稱
        @Default var locationName: String
        /// 緯度
        @Default var latitude: Int
        /// 經度
        @Default var longitude: Int
        /// 時間區間資料
        @Default var timePeriods: TimePeriod
        
        enum CodingKeys: String, CodingKey {
            case locationName = "LocationName"
            case latitude = "Latitude"
            case longitude = "Longitude"
            case timePeriods = "TimePeriods"
        }
    }
    
    /// 時間區間資料
    struct TimePeriod: Codable, DefaultValue {
        static var defaultValue: TideDataModel.TimePeriod = .init(date: "", tideRange: "", time: [])
        /// 日期
        @Default var date: String
        /// 潮汐變化
        @Default var tideRange: String
        /// 區段
        @Default var time: [Time]
        
        enum CodingKeys: String, CodingKey {
            case date = "Date"
            case tideRange = "TideRange"
            case time = "Time"
        }
    }
    
    /// 區段資料
    struct Time: Codable {
        /// 時段
        @Default var dateTime: String
        /// 潮水狀態
        @Default var tide: String
        /// 潮水高度
        @Default var tideHeights: [TideHeight]
        
        enum CodingKeys: String, CodingKey {
            case dateTime = "AboveTWVD"
            case tide = "AboveLocalMSL"
            case tideHeights = "AboveChartDatum"
        }
    }
    
    /// 潮水高度
    struct TideHeight: Codable {
        /// 海平面以上的高度（相對於台灣基準面，通常是指潮位相對於台灣的基準面）
        @Default var aboveTWVD: String
        /// 海平面以上的高度（相對於當地基準面，通常是當地的潮位基準面）
        @Default var aboveLocalMSL: Int
        /// 海平面以上的高度（相對於水圖基準面，通常是對應於水位圖的基準面）
        @Default var aboveChartDatum: Int
        
        enum CodingKeys: String, CodingKey {
            case aboveTWVD = "AboveTWVD"
            case aboveLocalMSL = "AboveLocalMSL"
            case aboveChartDatum = "AboveChartDatum"
        }
        
    }
}
