//
//  MarineFishingDetailModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/4/10.
//

import Foundation

// MARK: - DefaultValue Conformances for Enums

extension OverallLevel: DefaultValue {
    static var defaultValue: OverallLevel { .unknown }
}

extension RiskLevel: DefaultValue {
    static var defaultValue: RiskLevel { .unknown }
}

extension ColorToken: DefaultValue {
    static var defaultValue: ColorToken { .gray }
}

extension TideStage: DefaultValue {
    static var defaultValue: TideStage { .unknown }
}

extension TideType: DefaultValue {
    static var defaultValue: TideType { .UNKNOWN }
}

// MARK: - DefaultValue Conformances for Display Structs

extension PrimarySecondaryDisplay: DefaultValue {
    static var defaultValue = PrimarySecondaryDisplay(primary: "--", secondary: "--")
}

extension PrimaryDisplay: DefaultValue {
    static var defaultValue = PrimaryDisplay(primary: "--")
}

extension TideHeight: DefaultValue {
    static var defaultValue = TideHeight(aboveTWVDcm: nil, aboveLocalMSLcm: nil, aboveChartDatumcm: nil)
}

extension TideEventDisplay: DefaultValue {
    static var defaultValue = TideEventDisplay(time: "--", height: "--")
}

// MARK: - Root

struct MarineFishingDetailResponse: Codable, DefaultValue {
    static var defaultValue = MarineFishingDetailResponse(
        requestedLocation: "",
        resolvedLocation: "",
        fallbackUsed: false,
        fallbackReason: nil,
        nearestStation: nil,
        meta: .defaultValue,
        location: .defaultValue,
        ui: .defaultValue,
        raw: .defaultValue
    )
    /// 前端請求的城市名稱
    @Default var requestedLocation: String
    /// 後端實際使用的城市名稱（fallback 時可能不同）
    @Default var resolvedLocation: String
    /// 是否啟用了 fallback 資料
    var fallbackUsed: Bool
    /// fallback 原因（fallbackUsed 為 true 時才有值）
    var fallbackReason: String?
    /// 最近的氣象站名稱（fallbackUsed 為 true 時才有值）
    var nearestStation: String?
    @Default var meta: Meta
    @Default var location: LocationInfo
    @Default var ui: UIData
    @Default var raw: RawDataSection
}

// MARK: - Meta

struct Meta: Codable, DefaultValue {
    static var defaultValue = Meta(
        updatedAt: "", timezone: "", sourceDatasets: [],
        query: .defaultValue, units: .defaultValue
    )
    @Default var updatedAt: String
    @Default var timezone: String
    @Default var sourceDatasets: [String]
    @Default var query: Query
    @Default var units: Units
}

struct Query: Codable, DefaultValue {
    static var defaultValue = Query(location: "", from: "", to: "")
    @Default var location: String
    @Default var from: String
    @Default var to: String
}

struct Units: Codable, DefaultValue {
    static var defaultValue = Units(
        temperature: "", waveHeight: "", wavePeriod: "",
        windSpeed: "", distance: "", tideHeight: ""
    )
    @Default var temperature: String
    @Default var waveHeight: String
    @Default var wavePeriod: String
    @Default var windSpeed: String
    @Default var distance: String
    @Default var tideHeight: String
}

// MARK: - Location

struct LocationInfo: Codable, DefaultValue {
    static var defaultValue = LocationInfo(
        id: nil, name: "", city: "",
        latitude: nil, longitude: nil, currentTime: ""
    )
    var id: String?
    @Default var name: String
    @Default var city: String
    var latitude: Double?
    var longitude: Double?
    @Default var currentTime: String
}

// MARK: - UI

struct UIData: Codable, DefaultValue {
    static var defaultValue = UIData(
        summary: .defaultValue, recommendation: .defaultValue,
        oceanConditions: .defaultValue, tide: .defaultValue,
        weather: .defaultValue, indicators: .defaultValue
    )
    @Default var summary: Summary
    @Default var recommendation: Recommendation
    @Default var oceanConditions: OceanConditions
    @Default var tide: TideUI
    @Default var weather: WeatherUI
    @Default var indicators: Indicators
}

struct Summary: Codable, DefaultValue {
    static var defaultValue = Summary(
        headline: "", shortLabel: "", overallLevel: .unknown,
        score: 0, reasons: [], warnings: []
    )
    @Default var headline: String
    @Default var shortLabel: String
    @Default var overallLevel: OverallLevel
    @Default var score: Int
    @Default var reasons: [CodeLabel]
    @Default var warnings: [CodeLabel]
}

struct CodeLabel: Codable {
    @Default var code: String
    @Default var label: String
}

enum OverallLevel: String, Codable {
    case good, moderate, danger, unknown
}

struct Recommendation: Codable, DefaultValue {
    static var defaultValue = Recommendation(primary: "", secondary: "", tags: [])
    @Default var primary: String
    @Default var secondary: String
    @Default var tags: [RecommendationTag]
}

struct RecommendationTag: Codable {
    @Default var code: String
    @Default var label: String
    @Default var level: String
}

// MARK: - Ocean Conditions

struct OceanConditions: Codable, DefaultValue {
    static var defaultValue = OceanConditions(
        station: .defaultValue, sources: nil,
        wave: .defaultValue, wind: .defaultValue,
        sea: .defaultValue, current: .defaultValue
    )
    @Default var station: Station
    /// 各欄位各自的最近可用來源站（分欄位挑最近有值的站）
    var sources: OceanConditionSources?
    @Default var wave: Wave
    @Default var wind: Wind
    @Default var sea: Sea
    @Default var current: Current
}

/// 各海象欄位的資料來源站資訊
struct OceanConditionSources: Codable {
    var wave: MarineFieldSource?
    var wind: MarineFieldSource?
    var sea: MarineFieldSource?
    var current: MarineFieldSource?
}

/// 單一欄位的來源測站摘要
struct MarineFieldSource: Codable {
    var stationId: String?
    var stationName: String?
    var distanceKm: Double?
}

struct Station: Codable, DefaultValue {
    static var defaultValue = Station(
        id: nil, name: nil, attribute: nil,
        countyName: nil, townName: nil, areaName: nil,
        distanceKm: nil, observedAt: nil
    )
    var id: String?
    var name: String?
    var attribute: String?
    var countyName: String?
    var townName: String?
    var areaName: String?
    var distanceKm: Double?
    var observedAt: String?
}

struct Wave: Codable, DefaultValue {
    static var defaultValue = Wave(
        heightM: nil, periodSec: nil, directionDeg: nil, directionText: nil,
        level: .unknown, colorToken: .gray, display: .defaultValue
    )
    var heightM: Double?
    var periodSec: Double?
    var directionDeg: Double?
    var directionText: String?
    @Default var level: RiskLevel
    @Default var colorToken: ColorToken
    @Default var display: PrimarySecondaryDisplay
}

struct Wind: Codable, DefaultValue {
    static var defaultValue = Wind(
        speedMs: nil, maxSpeedMs: nil, directionDeg: nil, directionText: nil,
        level: .unknown, colorToken: .gray, display: .defaultValue
    )
    var speedMs: Double?
    var maxSpeedMs: Double?
    var directionDeg: Double?
    var directionText: String?
    @Default var level: RiskLevel
    @Default var colorToken: ColorToken
    @Default var display: PrimarySecondaryDisplay
}

struct Sea: Codable, DefaultValue {
    static var defaultValue = Sea(temperatureC: nil, display: .defaultValue)
    var temperatureC: Double?
    @Default var display: PrimaryDisplay
}

struct Current: Codable, DefaultValue {
    static var defaultValue = Current(speedMs: nil, directionDeg: nil, directionText: nil)
    var speedMs: Double?
    var directionDeg: Double?
    var directionText: String?
}

enum RiskLevel: String, Codable {
    case safe, moderate, danger, unknown
}

enum ColorToken: String, Codable {
    case green, yellow, red, gray
}

struct PrimarySecondaryDisplay: Codable {
    @Default var primary: String
    @Default var secondary: String
}

struct PrimaryDisplay: Codable {
    @Default var primary: String
}

// MARK: - Tide UI

struct TideUI: Codable, DefaultValue {
    static var defaultValue = TideUI(now: .defaultValue, nextEvent: nil, today: .defaultValue)
    @Default var now: TideNow
    var nextEvent: TideEventUI?
    @Default var today: TideToday
}

struct TideNow: Codable, DefaultValue {
    static var defaultValue = TideNow(
        observedAt: "", stage: .unknown, stageLabel: "--",
        icon: "questionmark", progressToNextEvent: nil, currentRelativePosition: "unknown"
    )
    @Default var observedAt: String
    @Default var stage: TideStage
    @Default var stageLabel: String
    @Default var icon: String
    var progressToNextEvent: Double?
    @Default var currentRelativePosition: String
}

enum TideStage: String, Codable {
    case rising, falling, slack, unknown
}

struct TideEventUI: Codable {
    @Default var dateTime: String
    @Default var type: TideType
    @Default var label: String
    @Default var tideLabel: String
    @Default var height: TideHeight
    @Default var display: TideEventDisplay
}

enum TideType: String, Codable {
    case HIGH, LOW, UNKNOWN
}

struct TideHeight: Codable {
    var aboveTWVDcm: Double?
    var aboveLocalMSLcm: Double?
    var aboveChartDatumcm: Double?
}

struct TideEventDisplay: Codable {
    @Default var time: String
    @Default var height: String
}

struct TideToday: Codable, DefaultValue {
    static var defaultValue = TideToday(
        date: "", lunarDate: "", tideRange: "",
        events: [], timeline: .defaultValue
    )
    @Default var date: String
    @Default var lunarDate: String
    @Default var tideRange: String
    @Default var events: [TideEventTimelineItem]
    @Default var timeline: TideTimeline
}

struct TideEventTimelineItem: Codable {
    @Default var id: String
    @Default var dateTime: String
    @Default var type: TideType
    @Default var label: String
    @Default var tideLabel: String
    var heightAboveChartDatumCm: Double?
}

struct TideTimeline: Codable, DefaultValue {
    static var defaultValue = TideTimeline(
        startTime: "", endTime: "", currentTime: "",
        points: [], currentMarker: .defaultValue
    )
    @Default var startTime: String
    @Default var endTime: String
    @Default var currentTime: String
    @Default var points: [TimelinePoint]
    @Default var currentMarker: Marker
}

struct TimelinePoint: Codable {
    @Default var time: String
    @Default var x: Double
    @Default var y: Double
    @Default var type: TideType
}

struct Marker: Codable, DefaultValue {
    static var defaultValue = Marker(x: 0, y: 0)
    @Default var x: Double
    @Default var y: Double
}

// MARK: - Weather UI

struct WeatherUI: Codable, DefaultValue {
    static var defaultValue = WeatherUI(current: .defaultValue, hourly: [])
    @Default var current: WeatherCurrent
    @Default var hourly: [WeatherHourly]
}

struct WeatherCurrent: Codable, DefaultValue {
    static var defaultValue = WeatherCurrent(
        description: "", icon: "questionmark.circle",
        temperatureC: nil, feelsLikeC: nil, popPercent: nil
    )
    @Default var description: String
    @Default var icon: String
    var temperatureC: Double?
    var feelsLikeC: Double?
    var popPercent: Double?
}

struct WeatherHourly: Codable {
    var dateTime: String?
    @Default var displayTime: String
    @Default var icon: String
    @Default var description: String
    var temperatureC: Double?
    var popPercent: Double?
}

// MARK: - Indicators

struct Indicators: Codable, DefaultValue {
    static var defaultValue = Indicators(
        fishingSuitability: .defaultValue,
        shoreSafety: .defaultValue,
        offshoreSafety: .defaultValue,
        waveRisk: .defaultValue,
        windRisk: .defaultValue
    )
    @Default var fishingSuitability: Suitability
    @Default var shoreSafety: SafetyLabel
    @Default var offshoreSafety: SafetyLabel
    @Default var waveRisk: SafetyLabel
    @Default var windRisk: SafetyLabel
}

struct Suitability: Codable, DefaultValue {
    static var defaultValue = Suitability(level: .unknown, score: 0, label: "")
    @Default var level: OverallLevel
    @Default var score: Int
    @Default var label: String
}

struct SafetyLabel: Codable, DefaultValue {
    static var defaultValue = SafetyLabel(level: .unknown, label: "")
    @Default var level: RiskLevel
    @Default var label: String
}

// MARK: - Raw

struct RawDataSection: Codable, DefaultValue {
    static var defaultValue = RawDataSection(marineStations: [], weather36h: [], tideDays: [])
    @Default var marineStations: [MarineStationRaw]
    @Default var weather36h: [Weather36hRaw]
    @Default var tideDays: [TideDayRaw]
}

struct MarineStationRaw: Codable {
    var stationId: String?
    var stationName: String?
    var stationNameEN: String?
    var stationAttribute: String?
    var stationLongitude: Double?
    var stationLatitude: Double?
    var countyName: String?
    var townName: String?
    var areaName: String?
    var latest: MarineLatestRaw?
}

struct MarineLatestRaw: Codable {
    var observedAt: String?
    var waveHeightM: Double?
    var waveDirectionDeg: Double?
    var waveDirectionText: String?
    var wavePeriodSec: Double?
    var seaTemperatureC: Double?
    var windSpeedMs: Double?
    var windDirectionDeg: Double?
    var windDirectionText: String?
    var maxWindSpeedMs: Double?
    var currentDirectionDeg: Double?
    var currentDirectionText: String?
    var currentSpeedMs: Double?
}

struct Weather36hRaw: Codable {
    @Default var startTime: String
    @Default var endTime: String
    @Default var description: String
    var minTempC: Double?
    var maxTempC: Double?
    var avgTempC: Double?
    var comfort: String?
    var popPercent: Double?
}

struct TideDayRaw: Codable {
    @Default var date: String
    var lunarDate: String?
    var tideRange: String?
    @Default var events: [TideEventRaw]
}

struct TideEventRaw: Codable {
    @Default var dateTime: String
    @Default var tide: String
    @Default var type: TideType
    @Default var tideHeights: TideHeight
}
