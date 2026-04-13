//
//  LocationDetailView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/4/10.
//

import SwiftUI

// MARK: - Main View

struct LocationDetailView: View {
    let response: MarineFishingDetailResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    LocationHeroSection(
                        location: response.location,
                        summary: response.ui.summary
                    )
                    OceanConditionsCard(
                        ocean: response.ui.oceanConditions,
                        shoreSafety: response.ui.indicators.shoreSafety
                    )
                    TideCard(tide: response.ui.tide)
                    WeatherCard(weather: response.ui.weather)
                    RecommendationSection(
                        primary: response.ui.recommendation.primary,
                        tags: response.ui.recommendation.tags
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 72)
                .padding(.bottom, 32)
            }

            // Navigation bar overlay
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.teal)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Spacer()

                Text("Location Details")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Button(action: {}) {
                    Image(systemName: "star")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.teal)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Hero Section

private struct LocationHeroSection: View {
    let location: LocationInfo
    let summary: Summary

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color.teal.opacity(0.12), Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.city.isEmpty ? "Unknown" : location.city)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.teal.opacity(0.75))
                            .kerning(0.5)
                            .textCase(.uppercase)

                        Text(location.name.isEmpty ? "--" : location.name)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(Color(.label))
                    }

                    Spacer()

                    Text(formattedCurrentTime)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.teal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground).opacity(0.85))
                                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                        )
                }

                // Headline banner
                HStack(spacing: 12) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 22))
                        .foregroundColor(.white)

                    Text(summary.headline.isEmpty ? "--" : summary.headline)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.teal)
                )
            }
            .padding(20)
        }
    }

    private var formattedCurrentTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: location.currentTime)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: location.currentTime)
        }
        guard let d = date else { return "--:--" }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }
}

// MARK: - Ocean Conditions Card

private struct OceanConditionsCard: View {
    let ocean: OceanConditions
    let shoreSafety: SafetyLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Header ──────────────────────────────────────────
            HStack {
                Text("海況資訊")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                StatusBadge(level: shoreSafety.level)
            }

            // ── 主顯示站 ─────────────────────────────────────────
            if let name = ocean.station.name {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.teal)
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(.secondaryLabel))
                    if let dist = ocean.station.distanceKm {
                        Text(String(format: "（%.2f km）", dist))
                            .font(.system(size: 12))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }

            // ── 浪況 block ───────────────────────────────────────
            OceanMetricBlock(
                icon: "water.waves",
                title: "浪況",
                sourceLabel: "浪況資料來源",
                source: ocean.sources?.wave,
                rows: [
                    ("浪高", ocean.wave.display.primary),
                    ("週期", ocean.wave.display.secondary)
                ]
            )

            Divider()

            // ── 風速 block ───────────────────────────────────────
            OceanMetricBlock(
                icon: "wind",
                title: "風速",
                sourceLabel: "風速資料來源",
                source: ocean.sources?.wind,
                rows: [
                    ("風速", ocean.wind.display.primary),
                    ("最大風速", ocean.wind.display.secondary)
                ]
            )

            Divider()

            // ── 海溫 block ───────────────────────────────────────
            OceanMetricBlock(
                icon: "thermometer.medium",
                title: "海溫",
                sourceLabel: "海溫資料來源",
                source: ocean.sources?.sea,
                rows: [
                    ("水溫", ocean.sea.display.primary)
                ]
            )

            // ── 海流 block（有值才顯示）──────────────────────────
            if ocean.current.speedMs != nil || ocean.sources?.current != nil {
                Divider()
                OceanMetricBlock(
                    icon: "arrow.clockwise.circle",
                    title: "海流",
                    sourceLabel: "海流資料來源",
                    source: ocean.sources?.current,
                    rows: [
                        ("流速", ocean.current.speedMs.map { String(format: "%.1f m/s", $0) } ?? "--"),
                        ("方向", ocean.current.directionText ?? "--")
                    ]
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

/// 單一海象類別的 metric block：顯示數值列 + 資料來源站
private struct OceanMetricBlock: View {
    let icon: String
    let title: String
    let sourceLabel: String
    let source: MarineFieldSource?
    /// (label, value) 的數值列
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題列
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.teal)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(.label))
            }

            // 數值列
            HStack(spacing: 16) {
                ForEach(rows, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                            .textCase(.uppercase)
                            .kerning(0.3)
                        Text(value.isEmpty ? "--" : value)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color(.label))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    if rows.last?.0 != label {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 1, height: 28)
                    }
                }
                Spacer()
            }

            // 資料來源
            SourceTagView(label: sourceLabel, source: source)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// 資料來源小標籤
private struct SourceTagView: View {
    let label: String
    let source: MarineFieldSource?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 10))
                .foregroundColor(source != nil ? Color.teal.opacity(0.7) : Color(.tertiaryLabel))

            if let src = source, let name = src.stationName {
                Group {
                    Text(label + "：")
                        .foregroundColor(Color(.secondaryLabel))
                    + Text(name)
                        .foregroundColor(Color(.label))
                    + Text(src.distanceKm.map { String(format: "（%.2f km）", $0) } ?? "")
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .font(.system(size: 11))
            } else {
                Text(label + "：無可用測站")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
    }
}

// MARK: - Tide Card

private struct TideCard: View {
    let tide: TideUI

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Tide")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                HStack(spacing: 4) {
                    Text(tide.now.stageLabel.isEmpty ? "--" : tide.now.stageLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.teal)
                    Image(systemName: tide.now.stage.arrowIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.teal)
                }
            }

            // Tide curve
            TideCurveView(
                points: tide.today.timeline.points,
                currentMarker: tide.today.timeline.currentMarker
            )
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            // Next event
            if let next = tide.nextEvent {
                HStack {
                    Text("Next Tide")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(.label))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(next.tideLabel) at \(next.display.time)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.teal)
                        Text("(\(next.display.height))")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.teal.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Tide Curve View

private struct TideCurveView: View {
    let points: [TimelinePoint]
    let currentMarker: Marker

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let hPad: CGFloat = 16
            let vPad: CGFloat = 12
            let innerW = w - hPad * 2
            let innerH = h - vPad * 2

            let sorted = points.sorted { $0.x < $1.x }
            let chartPts = sorted.map {
                CGPoint(
                    x: hPad + $0.x * innerW,
                    y: vPad + (1.0 - $0.y) * innerH
                )
            }

            ZStack {
                // Area fill under curve
                areaPath(pts: chartPts, bottom: h)
                    .fill(
                        LinearGradient(
                            colors: [Color.teal.opacity(0.22), Color.teal.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Curve line
                linePath(pts: chartPts)
                    .stroke(
                        Color.teal,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                // Tide event markers
                ForEach(Array(sorted.enumerated()), id: \.offset) { _, pt in
                    let x = hPad + pt.x * innerW
                    let y = vPad + (1.0 - pt.y) * innerH

                    ZStack {
                        Circle().fill(Color(.systemBackground)).frame(width: 10, height: 10)
                        Circle().stroke(Color.teal, lineWidth: 2).frame(width: 10, height: 10)
                    }
                    .position(x: x, y: y)

                    Text(pt.type == .HIGH ? "H" : "L")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.teal)
                        .position(
                            x: x,
                            y: pt.type == .HIGH
                                ? max(y - 14, vPad - 2)
                                : min(y + 14, h - vPad + 2)
                        )
                }

                // Current position marker
                let cx = hPad + currentMarker.x * innerW
                let cy = vPad + (1.0 - currentMarker.y) * innerH
                ZStack {
                    Circle().fill(Color.teal).frame(width: 12, height: 12)
                    Circle().fill(Color.white).frame(width: 5, height: 5)
                }
                .position(x: cx, y: cy)
            }
        }
    }

    private func linePath(pts: [CGPoint]) -> Path {
        Path { path in
            guard pts.count >= 2 else {
                if let p = pts.first { path.move(to: p) }
                return
            }
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let prev = pts[i - 1]
                let curr = pts[i]
                let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.45, y: prev.y)
                let cp2 = CGPoint(x: curr.x - (curr.x - prev.x) * 0.45, y: curr.y)
                path.addCurve(to: curr, control1: cp1, control2: cp2)
            }
        }
    }

    private func areaPath(pts: [CGPoint], bottom: CGFloat) -> Path {
        Path { path in
            guard pts.count >= 2, let first = pts.first, let last = pts.last else { return }
            path.move(to: CGPoint(x: first.x, y: bottom))
            path.addLine(to: first)
            for i in 1..<pts.count {
                let prev = pts[i - 1]
                let curr = pts[i]
                let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.45, y: prev.y)
                let cp2 = CGPoint(x: curr.x - (curr.x - prev.x) * 0.45, y: curr.y)
                path.addCurve(to: curr, control1: cp1, control2: cp2)
            }
            path.addLine(to: CGPoint(x: last.x, y: bottom))
            path.closeSubpath()
        }
    }
}

// MARK: - Weather Card

private struct WeatherCard: View {
    let weather: WeatherUI

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weather")
                .font(.system(size: 18, weight: .bold))

            if weather.hourly.isEmpty {
                Text("No forecast data available")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(weather.hourly.enumerated()), id: \.offset) { index, hourly in
                            HourlyWeatherItem(hourly: hourly, isActive: index == 0)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

private struct HourlyWeatherItem: View {
    let hourly: WeatherHourly
    let isActive: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(hourly.displayTime.isEmpty ? "--" : hourly.displayTime)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .foregroundColor(isActive ? .white.opacity(0.85) : Color(.secondaryLabel))

            Image(systemName: safeSFSymbol(hourly.icon))
                .font(.system(size: 22))
                .symbolRenderingMode(.multicolor)
                .foregroundColor(isActive ? .white : .teal)

            if let temp = hourly.temperatureC {
                Text(String(format: "%.0f°", temp))
                    .font(.system(size: 15, weight: isActive ? .heavy : .semibold))
                    .foregroundColor(isActive ? .white : Color(.label))
            } else {
                Text("--°")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isActive ? .white.opacity(0.7) : Color(.tertiaryLabel))
            }
        }
        .frame(minWidth: 68)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isActive ? AnyShapeStyle(Color.teal) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                .shadow(color: isActive ? Color.teal.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
    }

    /// SF Symbol 白名單，防止無效名稱導致 icon 消失
    private func safeSFSymbol(_ name: String) -> String {
        let known: Set<String> = [
            "sun.max.fill", "cloud.sun.fill", "cloud.fill",
            "cloud.rain.fill", "cloud.heavyrain.fill", "cloud.bolt.fill",
            "cloud.drizzle.fill", "cloud.snow.fill", "wind",
            "snowflake", "thermometer.medium", "humidity.fill"
        ]
        return known.contains(name) ? name : "cloud.fill"
    }
}

// MARK: - Recommendation Section

private struct RecommendationSection: View {
    let primary: String
    let tags: [RecommendationTag]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Recommendation")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 4)

            WrapLayout(spacing: 10, runSpacing: 10) {
                if !primary.isEmpty {
                    RecommendationChip(
                        icon: "fish.fill",
                        text: primary,
                        level: "safe"
                    )
                }
                ForEach(tags, id: \.code) { tag in
                    RecommendationChip(
                        icon: tag.sfSymbol,
                        text: tag.label,
                        level: tag.level
                    )
                }
            }
        }
    }
}

private struct RecommendationChip: View {
    let icon: String
    let text: String
    let level: String

    private var chipColor: Color {
        switch level.lowercased() {
        case "safe", "good":   return .teal
        case "caution", "moderate": return .orange
        case "danger":         return .red
        default:               return .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(chipColor)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(chipColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(chipColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(chipColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Shared Sub-Views

private struct StatusBadge: View {
    let level: RiskLevel

    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.badgeColor)
                .frame(width: 8, height: 8)
                .scaleEffect(pulsing ? 1.3 : 1.0)
                .animation(
                    level == .safe
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )
                .onAppear { if level == .safe { pulsing = true } }

            Text(level.badgeLabel)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(level.badgeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(level.badgeColor.opacity(0.1))
        )
    }
}

private struct MetricTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.secondaryLabel))

            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Model Display Extensions

private extension RiskLevel {
    var badgeColor: Color {
        switch self {
        case .safe:    return Color(red: 0.13, green: 0.60, blue: 0.35)
        case .moderate: return .orange
        case .danger:  return .red
        case .unknown: return .gray
        }
    }
    var badgeLabel: String {
        switch self {
        case .safe:    return "Safe"
        case .moderate: return "Caution"
        case .danger:  return "Danger"
        case .unknown: return "Unknown"
        }
    }
}

private extension TideStage {
    var arrowIcon: String {
        switch self {
        case .rising:  return "arrow.up"
        case .falling: return "arrow.down"
        case .slack:   return "minus"
        case .unknown: return "questionmark"
        }
    }
}

private extension RecommendationTag {
    var sfSymbol: String {
        switch code {
        case "SHORE_STATUS":   return "figure.fishing"
        case "OFFSHORE_STATUS": return "ferry.fill"
        case "WIND":           return "wind"
        case "WAVE":           return "water.waves"
        case "RAIN":           return "cloud.rain.fill"
        default:               return "info.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    LocationDetailView(response: .defaultValue)
}
