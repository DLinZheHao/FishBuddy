//
//  Forecast36HourModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/4/13.
//
//  對應 `/forecast/36-hour?lat=&lon=` 以及 `/forecast/36-hour?city=` 的回應格式
//  (selectionMode = "nearest" | "city"，data 為單筆 object)

import Foundation

// MARK: - Root Response

struct Forecast36HourResponse: Codable {
    let meta: F36Meta
    let data: Forecast36HourData
}

// MARK: - Meta

struct F36Meta: Codable {
    /// 資料更新時間（ISO8601）
    let updatedAt: String?
    let timezone: String?
    /// "nearest" | "city" | "list"
    let selectionMode: String?
    let requestedCity: String?
    let requestedLat: Double?
    let requestedLon: Double?
    /// 後端實際解析出來的城市名稱
    let resolvedCity: String?
    /// 距離（selectionMode = "nearest" 時才有值）
    let distanceKm: Double?
}

// MARK: - City Data

struct Forecast36HourData: Codable {
    let city: String
    let dateRange: F36DateRange?
    let sun: F36Sun?
    let moon: F36Moon?
    let currentObservation: F36CurrentObservation?
    let summary: F36Summary?
    let timeline: [F36TimelineItem]

    enum CodingKeys: String, CodingKey {
        case city, dateRange, sun, moon
        case currentObservation, summary, timeline
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        city            = (try? c.decode(String.self,              forKey: .city))            ?? ""
        dateRange       = try? c.decodeIfPresent(F36DateRange.self,           forKey: .dateRange)
        sun             = try? c.decodeIfPresent(F36Sun.self,                 forKey: .sun)
        moon            = try? c.decodeIfPresent(F36Moon.self,                forKey: .moon)
        currentObservation = try? c.decodeIfPresent(F36CurrentObservation.self, forKey: .currentObservation)
        summary         = try? c.decodeIfPresent(F36Summary.self,             forKey: .summary)
        timeline        = (try? c.decodeIfPresent([F36TimelineItem].self,      forKey: .timeline)) ?? []
    }
}

// MARK: - Date Range

struct F36DateRange: Codable {
    /// "yyyy-MM-dd"
    let from: String?
    let to: String?
}

// MARK: - Sun

struct F36Sun: Codable {
    /// "HH:mm"
    let sunrise: String?
    let sunset: String?
    let civilDawn: String?
    let civilDusk: String?
    let solarNoon: String?
    let minutesToSunrise: Int?
    let minutesToSunset: Int?
}

// MARK: - Moon

struct F36Moon: Codable {
    let moonrise: String?
    let moonTransit: String?
    let moonset: String?
}

// MARK: - Current Observation

struct F36CurrentObservation: Codable {
    let station: F36ObsStation?
    let weatherText: String?
    let temperatureC: Double?
    let humidityPercent: Int?
    let windSpeedMs: Double?
    let windDirectionDeg: Double?
    let pressureHpa: Double?
    let peakGustSpeedMs: Double?
    let dailyHighC: Double?
    let dailyLowC: Double?
    let rainNowMm: Double?
    let rainPast1hMm: Double?
    let rainPast3hMm: Double?
    let rainPast24hMm: Double?
}

struct F36ObsStation: Codable {
    let weather: F36StationInfo?
    let rain: F36StationInfo?
}

struct F36StationInfo: Codable {
    let id: String?
    let name: String?
    let countyName: String?
    let townName: String?
    /// ISO8601
    let observedAt: String?
}

// MARK: - Summary

struct F36Summary: Codable {
    let headline: String?
    let bestWindow: F36BestWindow?
}

struct F36BestWindow: Codable {
    /// ISO8601
    let startTime: String?
    /// ISO8601
    let endTime: String?
    let score: Int?
    let reason: String?
}

// MARK: - Timeline

struct F36TimelineItem: Codable, Identifiable {
    /// SwiftUI identity：用 startTime 當 id，確保 diffing 穩定
    var id: String { startTime ?? UUID().uuidString }

    /// ISO8601
    let startTime: String?
    /// ISO8601
    let endTime: String?
    let weather: F36TimelineWeather?
    let temperature: F36TimelineTemperature?
    let rain: F36TimelineRain?
    let comfort: F36TimelineComfort?
    let derived: F36TimelineDerived?
}

struct F36TimelineWeather: Codable {
    let description: String?
    let detail: String?
    /// SF Symbol name，例如 "cloud.sun.fill"
    let icon: String?
}

struct F36TimelineTemperature: Codable {
    let minC: Double?
    let maxC: Double?
    let avgC: Double?
}

struct F36TimelineRain: Codable {
    let pop12hPercent: Int?
    /// "low" | "moderate" | "high"
    let riskLevel: String?
}

struct F36TimelineComfort: Codable {
    let text: String?
    let level: String?
}

struct F36TimelineDerived: Codable {
    let outdoorScore: Int?
    /// null 代表混合時段
    let isDaylight: Bool?
    let heatRisk: String?
    let rainRisk: String?
}
