//
//  CityWeatherView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/4/13.
//
//  天氣頁主視圖：根據 WeatherLobbyVM.forecastResponse 渲染單城市天氣概覽
//  對應設計稿的 5 個區塊：Hero / BestWindow / CurrentObs / Timeline / Sun&Moon

import SwiftUI

// MARK: - Design tokens (from HTML Tailwind config)

private extension Color {
    static let cwPrimary        = Color(red: 0.000, green: 0.396, blue: 0.463) // #006576
    static let cwPrimaryDark    = Color(red: 0.063, green: 0.502, blue: 0.580) // #108094
    static let cwSecondary      = Color(red: 0.251, green: 0.392, blue: 0.412) // #406469
    static let cwTertiary       = Color(red: 0.620, green: 0.239, blue: 0.000) // #9e3d00
    static let cwSurface        = Color(red: 0.976, green: 0.976, blue: 0.984) // #f9f9fb
    static let cwSurfaceLow     = Color(red: 0.953, green: 0.953, blue: 0.961) // #f3f3f5
    static let cwSurfaceLowest  = Color.white
    static let cwSurfaceHigh    = Color(red: 0.910, green: 0.910, blue: 0.918) // #e8e8ea
    static let cwOnSurface      = Color(red: 0.102, green: 0.110, blue: 0.114) // #1a1c1d
    static let cwOnSurfaceVar   = Color(red: 0.255, green: 0.278, blue: 0.333) // #414755
    static let cwSecContainer   = Color(red: 0.753, green: 0.902, blue: 0.925) // #c0e6ec
    static let cwOutlineVar     = Color(red: 0.757, green: 0.776, blue: 0.843) // #c1c6d7
    static let cwError          = Color(red: 0.729, green: 0.102, blue: 0.102) // #ba1a1a
}

// MARK: - Entry Point

struct CityWeatherView: View {
    @ObservedObject var vm: WeatherLobbyVM
    @State private var lastRefreshDate: Date?

    private var isRefreshEnabled: Bool {
        switch vm.listLoadingState {
        case .loaded, .error:
            return true
        case .idle, .loading:
            return false
        }
    }

    @ViewBuilder
    private var weatherScrollView: some View {
        ScrollView {
            switch vm.listLoadingState {
            case .idle, .loading:
                CityWeatherSkeletonView()
            case .loaded:
                if let response = vm.forecastResponse {
                    CityWeatherContentView(
                        data: response.data,
                        meta: response.meta,
                        isFetchingDetail: vm.isFetchingDetail,
                        isUsingDeviceLocation: vm.isUsingDeviceLocation,
                        onUseDeviceLocation: { vm.useDeviceLocation() },
                        onSelectCity: { vm.fetchWeatherForCityList($0) },
                        onShowLocationDetail: { vm.fetchLocationDetail(city: response.data.city) }
                    )
                } else {
                    CityWeatherSkeletonView()
                }
            case .error(let msg):
                let _ = print("介面錯誤訊息：\(msg)")
                CityWeatherErrorView(message: msg) {
                    vm.loadWeatherOnLaunch()
                }
            }
        }
    }

    private func handleRefresh() async {
        // Cooldown：2 秒內不重複觸發
        if let last = lastRefreshDate, Date().timeIntervalSince(last) < 2 { return }
        lastRefreshDate = Date()

        vm.refreshWeather()
        for await state in vm.$listLoadingState.values {
            guard state == .loading else { break }
        }
    }

    var body: some View {
        ZStack {
            Color.cwSurface.ignoresSafeArea()

            if isRefreshEnabled {
                weatherScrollView
                    .refreshable {
                        await handleRefresh()
                    }
            } else {
                weatherScrollView
            }
        }
    }
}

// MARK: - Skeleton

private struct CityWeatherSkeletonView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Header placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cwSurfaceLow)
                .frame(height: 56)
            // Hero
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cwSurfaceLow)
                .frame(height: 200)
            // Best window
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cwSurfaceLow)
                .frame(height: 120)
            // Obs
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cwSurfaceLow)
                .frame(height: 100)
            // Timeline × 2
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cwSurfaceLow)
                    .frame(height: 160)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Error

private struct CityWeatherErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(Color.cwError.opacity(0.8))
            Text("無法載入天氣資料")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.cwOnSurface)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color.cwOnSurfaceVar)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onRetry) {
                Text("重試")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(Color.cwPrimary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content View

private struct CityWeatherContentView: View {
    let data: Forecast36HourData
    let meta: F36Meta
    let isFetchingDetail: Bool
    let isUsingDeviceLocation: Bool
    let onUseDeviceLocation: () -> Void
    let onSelectCity: (String) -> Void
    let onShowLocationDetail: () -> Void

    @State private var showCityPicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cityHeaderSection
            heroCard
            if let bw = data.summary?.bestWindow { bestWindowCard(bw) }
            marineDetailEntryCard
            if let obs = data.currentObservation { currentObsCard(obs) }
            if !data.timeline.isEmpty { timelineSection }
            if data.sun != nil || data.moon != nil { sunMoonSection }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 88) // tab bar clearance
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(
                currentCity: data.city,
                isUsingDeviceLocation: isUsingDeviceLocation,
                onSelectCity: onSelectCity,
                onUseDeviceLocation: onUseDeviceLocation
            )
        }
    }

    // MARK: City Header

    private var cityHeaderSection: some View {
        VStack(spacing: 4) {
            if let from = data.dateRange?.from, let to = data.dateRange?.to {
                Text("\(shortDate(from)) ~ \(shortDate(to))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.cwOnSurfaceVar)
                    .tracking(0.3)
            }
            Button {
                showCityPicker = true
            } label: {
                HStack(spacing: 8) {
                    Text(data.city)
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundColor(Color.cwPrimary)
                    if meta.selectionMode == "nearest" {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color.cwPrimary.opacity(0.7))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.cwPrimary.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("選擇城市")
            .accessibilityHint("點擊以切換顯示的城市")
            Text("戶外與釣魚天氣概覽")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.cwOnSurface)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: Hero Card

    private var heroCard: some View {
        let obs = data.currentObservation
        return ZStack(alignment: .bottomTrailing) {
            // Gradient background
            LinearGradient(
                colors: [Color.cwPrimary, Color.cwPrimaryDark],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Decorative blur circle
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 180, height: 180)
                .blur(radius: 32)
                .offset(x: 44, y: 44)

            VStack(spacing: 0) {
                // Top row: headline + temp
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("目前天氣")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.85)
                        Text(data.summary?.headline ?? obs?.weatherText ?? "--")
                            .font(.system(size: 19, weight: .heavy))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(fmtTemp(obs?.temperatureC))
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let hi = obs?.dailyHighC, let lo = obs?.dailyLowC {
                            Text("\(fmtTempVal(hi))° / \(fmtTempVal(lo))°")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.85)
                        }
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.vertical, 14)

                // Stats row
                HStack(spacing: 0) {
                    heroStatItem(symbol: "humidity",
                                 label: "濕度",
                                 value: obs?.humidityPercent.map { "\($0)%" } ?? "--")
                    heroStatItem(symbol: "wind",
                                 label: "風速",
                                 value: obs?.windSpeedMs.map { fmtWind($0) } ?? "--")
                    heroStatItem(symbol: "gauge.medium",
                                 label: "氣壓",
                                 value: obs?.pressureHpa.map { "\(Int($0))hPa" } ?? "--")
                    heroStatItem(symbol: "cloud.rain",
                                 label: "降雨",
                                 value: obs?.rainNowMm.map { "\(fmtRain($0))mm" } ?? "--")
                }
            }
            .foregroundColor(.white)
            .padding(20)
        }
        .shadow(color: Color.cwPrimary.opacity(0.25), radius: 20, x: 0, y: 8)
    }

    private func heroStatItem(symbol: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18))
            Text(label)
                .font(.system(size: 10))
                .opacity(0.72)
            Text(value)
                .font(.system(size: 11, weight: .bold))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Best Window Card

    private func bestWindowCard(_ bw: F36BestWindow) -> some View {
        HStack(spacing: 0) {
            // Left accent bar
            Color.cwPrimary
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最佳活動時段")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.cwPrimary)
                            .tracking(1.4)
                        Text(fmtWindowRange(start: bw.startTime, end: bw.endTime))
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.cwOnSurface)
                    }
                    Spacer()
                    if let score = bw.score {
                        ZStack {
                            Circle().fill(Color.cwPrimaryDark)
                            Text("\(score)")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)
                        }
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.cwPrimary.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                }

                if let reason = bw.reason, !reason.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.cwPrimary)
                        Text(reason)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.cwOnSurfaceVar)
                    }
                }

                // Tags
                HStack(spacing: 8) {
                    ForEach(bestWindowTags(bw), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.cwPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.cwSurfaceLowest)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(18)
        }
        .background(Color.cwSurfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: Marine Detail Entry Card

    private var marineDetailEntryCard: some View {
        Button(action: onShowLocationDetail) {
            HStack(spacing: 0) {
                // Left accent bar
                Color.cwPrimary
                    .frame(width: 4)

                HStack(spacing: 14) {
                    // Icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cwSecContainer)
                        Image(systemName: "water.waves")
                            .font(.system(size: 18))
                            .foregroundColor(Color.cwPrimary)
                    }
                    .frame(width: 44, height: 44)

                    // Text
                    VStack(alignment: .leading, spacing: 3) {
                        Text("海釣現況速覽")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.cwOnSurface)
                        Text("波浪・海流・潮汐・建議")
                            .font(.system(size: 12))
                            .foregroundColor(Color.cwOnSurfaceVar)
                    }

                    Spacer()

                    // Right side: loading indicator or chevron
                    if isFetchingDetail {
                        ProgressView()
                            .tint(Color.cwPrimary)
                            .padding(.trailing, 4)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.cwPrimary.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.cwSurfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .disabled(isFetchingDetail)
        .buttonStyle(.plain)
    }

    // MARK: Current Observation Card

    private func currentObsCard(_ obs: F36CurrentObservation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Station header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cwSecContainer)
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.cwPrimary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(stationDisplayName(obs))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.cwOnSurface)
                    if let obsAt = obs.station?.weather?.observedAt {
                        Text("觀測時間: \(isoToTime(obsAt))")
                            .font(.system(size: 10))
                            .foregroundColor(Color.cwOnSurfaceVar)
                    }
                }
            }

            // Rainfall row
            HStack(spacing: 0) {
                rainCell(label: "1h 降雨", value: obs.rainPast1hMm)
                Divider()
                    .background(Color.cwOutlineVar.opacity(0.4))
                    .frame(width: 1, height: 40)
                rainCell(label: "3h 降雨", value: obs.rainPast3hMm)
                Divider()
                    .background(Color.cwOutlineVar.opacity(0.4))
                    .frame(width: 1, height: 40)
                rainCell(label: "24h 累積", value: obs.rainPast24hMm)
            }
            .padding(14)
            .background(Color.cwSurfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(20)
        .background(Color.cwSurfaceLowest)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func rainCell(label: String, value: Double?) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.cwOnSurfaceVar)
                .tracking(0.5)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value.map { fmtRain($0) } ?? "--")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color.cwPrimary)
                Text("mm")
                    .font(.system(size: 10))
                    .foregroundColor(Color.cwOnSurfaceVar)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("未來 36 小時預報")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.cwOnSurfaceVar)
                .tracking(1.5)
                .padding(.leading, 2)

            ForEach(data.timeline) { item in
                timelineCard(item)
            }
        }
    }

    private func timelineCard(_ item: F36TimelineItem) -> some View {
        VStack(spacing: 0) {
            // Top row: time + icon + temp
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fmtTimeRange(start: item.startTime, end: item.endTime))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.cwOnSurfaceVar)
                    HStack(spacing: 6) {
                        Image(systemName: item.weather?.icon ?? "cloud")
                            .font(.system(size: 22))
                            .foregroundColor(Color.cwPrimary)
                            .symbolRenderingMode(.multicolor)
                        Text(item.weather?.description ?? "--")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.cwOnSurface)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let avg = item.temperature?.avgC {
                        Text("\(Int(avg.rounded()))°")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(Color.cwPrimary)
                    }
                    if let lo = item.temperature?.minC, let hi = item.temperature?.maxC {
                        Text("\(Int(lo.rounded()))° - \(Int(hi.rounded()))°")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.cwOnSurfaceVar)
                    }
                }
            }

            // Stats row
            Rectangle()
                .fill(Color.cwSurfaceLow)
                .frame(height: 1)
                .padding(.vertical, 12)

            HStack(spacing: 0) {
                // Rain prob
                timelineStatCell(
                    symbol: "drop.fill",
                    label: "降雨機率",
                    value: item.rain?.pop12hPercent.map { "\($0)%" } ?? "--"
                )
                // Outdoor score
                timelineStatCell(
                    symbol: "figure.hiking",
                    label: "戶外指數",
                    value: item.derived?.outdoorScore.map { "\($0) / 100" } ?? "--"
                )
            }

            // Risk bar
            HStack(spacing: 0) {
                Spacer()
                riskTag(icon: "drop.triangle.fill",
                        label: "降雨風險",
                        level: item.rain?.riskLevel)
                Spacer()
                riskTag(icon: "thermometer.sun.fill",
                        label: "熱量蓄積",
                        level: item.derived?.heatRisk)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cwSurfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.cwSurfaceLowest)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.cwSurfaceLow, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private func timelineStatCell(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cwSurfaceLow)
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundColor(Color.cwPrimary)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(Color.cwOnSurfaceVar)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.cwOnSurface)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func riskTag(icon: String, label: String, level: String?) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(riskColor(level))
                .frame(width: 8, height: 8)
            Text("\(label): \(riskLabel(level))")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.cwOnSurface)
        }
    }

    // MARK: Sun & Moon Section

    private var sunMoonSection: some View {
        HStack(spacing: 12) {
            // Sun card
            if let sun = data.sun {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.cwTertiary)
                        Text("日出日落")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.cwOnSurface)
                    }
                    VStack(spacing: 6) {
                        HStack {
                            Text(sun.sunrise ?? "--")
                            Spacer()
                            Text(sun.sunset ?? "--")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(Color.cwOnSurfaceVar)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.cwSurfaceLow)
                                Capsule()
                                    .fill(
                                        LinearGradient(colors: [Color.cwTertiary.opacity(0.3), Color.cwTertiary],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: geo.size.width * sunProgress(sun))
                            }
                        }
                        .frame(height: 4)

                        if let mins = sun.minutesToSunset {
                            Text("距離日落 \(mins) 分鐘")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.cwTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if let mins = sun.minutesToSunrise {
                            Text("距離日出 \(mins) 分鐘")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.cwTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .padding(16)
                .background(Color.cwSurfaceLowest)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }

            // Moon card
            if let moon = data.moon {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.cwPrimary)
                        Text("月相月時")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.cwOnSurface)
                    }
                    VStack(spacing: 8) {
                        moonRow(label: "月出", value: moon.moonrise)
                        moonRow(label: "中天", value: moon.moonTransit)
                        moonRow(label: "月落", value: moon.moonset)
                    }
                }
                .padding(16)
                .background(Color.cwSurfaceLowest)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    private func moonRow(label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.cwOnSurfaceVar)
            Spacer()
            Text(value ?? "--")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.cwOnSurface)
        }
    }

    // MARK: - Formatters & Helpers

    private func shortDate(_ str: String) -> String {
        let parts = str.split(separator: "-")
        guard parts.count >= 3 else { return str }
        return "\(parts[1])-\(parts[2])"
    }

    private func isoToTime(_ isoString: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let date = f.date(from: isoString) {
            let d = DateFormatter()
            d.dateFormat = "HH:mm"
            d.timeZone = TimeZone(identifier: "Asia/Taipei")
            return d.string(from: date)
        }
        // fallback: 截取 "T14:00:00" 中的時間部分
        if let tRange = isoString.range(of: "T"),
           let plusRange = isoString.range(of: "+", range: tRange.upperBound..<isoString.endIndex) {
            let timePart = String(isoString[tRange.upperBound..<plusRange.lowerBound])
            return String(timePart.prefix(5))
        }
        return "--"
    }

    private func fmtWindowRange(start: String?, end: String?) -> String {
        let s = start.map { isoToTime($0) } ?? "--"
        let e = end.map { isoToTime($0) } ?? "--"
        return "\(s) - \(e)"
    }

    private func fmtTimeRange(start: String?, end: String?) -> String {
        let s = start.map { isoToTime($0) } ?? "--"
        let e = end.map { isoToTime($0) } ?? "--"
        return "\(s) ~ \(e)"
    }

    private func fmtTemp(_ val: Double?) -> String {
        guard let v = val else { return "--°" }
        return "\(Int(v.rounded()))°"
    }

    private func fmtTempVal(_ val: Double) -> String {
        String(format: "%.0f", val)
    }

    private func fmtWind(_ ms: Double) -> String {
        String(format: "%.1fm/s", ms)
    }

    private func fmtRain(_ mm: Double) -> String {
        mm == 0 ? "0" : String(format: "%.1f", mm)
    }

    private func stationDisplayName(_ obs: F36CurrentObservation) -> String {
        guard let info = obs.station?.weather else { return "--" }
        let name = info.name ?? ""
        let county = info.countyName ?? ""
        return county.isEmpty ? name : "\(name) (\(county))"
    }

    private func sunProgress(_ sun: F36Sun) -> CGFloat {
        // If we know minutesToSunset, infer approximate position in the solar arc
        if let toSunset = sun.minutesToSunset {
            // Assume 12-hour daylight window → 720 mins total
            let ratio = 1.0 - (Double(toSunset) / 720.0)
            return CGFloat(max(0.05, min(0.95, ratio)))
        }
        if let toSunrise = sun.minutesToSunrise {
            let ratio = 1.0 - (Double(toSunrise) / 720.0)
            return CGFloat(max(0.05, min(0.05, ratio)))
        }
        return 0.5
    }

    private func bestWindowTags(_ bw: F36BestWindow) -> [String] {
        var tags: [String] = []
        if let reason = bw.reason, !reason.isEmpty { tags.append(reason) }
        if let start = bw.startTime {
            let hour = Int(isoToTime(start).prefix(2)) ?? 12
            tags.append(hour >= 18 || hour < 6 ? "夜間" : "白天")
        }
        if let score = bw.score {
            tags.append(score >= 70 ? "高推薦" : score >= 50 ? "可考慮" : "謹慎")
        }
        return tags
    }

    private func riskLabel(_ level: String?) -> String {
        switch level {
        case "low":      return "低"
        case "moderate": return "中"
        case "high":     return "高"
        default:         return "--"
        }
    }

    private func riskColor(_ level: String?) -> Color {
        switch level {
        case "low":      return .green
        case "moderate": return Color.cwTertiary
        case "high":     return Color.cwError
        default:         return Color.cwOutlineVar
        }
    }
}

// MARK: - City Picker Sheet

private struct CityPickerSheet: View {
    let currentCity: String
    let isUsingDeviceLocation: Bool
    let onSelectCity: (String) -> Void
    let onUseDeviceLocation: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    /// 台灣 22 縣市，依地理區分組（使用 CWA 官方「臺」字寫法）
    private static let regions: [(name: String, cities: [String])] = [
        ("北部", ["基隆市", "臺北市", "新北市", "桃園市", "新竹市", "新竹縣", "宜蘭縣"]),
        ("中部", ["苗栗縣", "臺中市", "彰化縣", "南投縣", "雲林縣"]),
        ("南部", ["嘉義市", "嘉義縣", "臺南市", "高雄市", "屏東縣"]),
        ("東部", ["花蓮縣", "臺東縣"]),
        ("離島", ["澎湖縣", "金門縣", "連江縣"])
    ]

    private var filteredRegions: [(name: String, cities: [String])] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Self.regions }
        let normalized = q.replacingOccurrences(of: "台", with: "臺")
        return Self.regions.compactMap { region in
            let matched = region.cities.filter {
                $0.contains(q) || $0.contains(normalized)
            }
            return matched.isEmpty ? nil : (region.name, matched)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onUseDeviceLocation()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color.cwPrimary)
                                .frame(width: 22)
                            Text("使用目前位置")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.cwOnSurface)
                            Spacer()
                            if isUsingDeviceLocation {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.cwPrimary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                ForEach(filteredRegions, id: \.name) { region in
                    Section(region.name) {
                        ForEach(region.cities, id: \.self) { city in
                            Button {
                                onSelectCity(city)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(city)
                                        .font(.system(size: 15))
                                        .foregroundColor(Color.cwOnSurface)
                                    Spacer()
                                    if !isUsingDeviceLocation && city == currentCity {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.cwPrimary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if filteredRegions.isEmpty {
                    Section {
                        Text("找不到符合「\(searchText)」的城市")
                            .font(.system(size: 13))
                            .foregroundColor(Color.cwOnSurfaceVar)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜尋城市"
            )
            .navigationTitle("選擇城市")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                        .foregroundColor(Color.cwPrimary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CityWeatherView(vm: WeatherLobbyVM())
}
