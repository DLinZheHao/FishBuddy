//
//  WeatherView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/4/15.
//

import Foundation
import SwiftUI

struct WeatherView: View {
    /// ViewModel
    @ObservedObject var vm: WeatherLobbyVM
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("天氣預報")
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)
                    Divider()
                    
                    SearchBar(text: $vm.searchText)
                        .padding(.horizontal, 16)
                }
                
                if let cityData = vm.weatherResponse?.data {
                    VStack(alignment: .leading, spacing: 16) {
                       ForEach(cityData.filter { cityWeather in
                           let keyword = vm.searchText.lowercased()
                           return keyword.isEmpty ||
                               cityWeather.city.lowercased().contains(keyword) ||
                               cityWeather.weather.contains(where: { weather in
                                   weather.description.lowercased().contains(keyword) ||
                                   weather.comfort.lowercased().contains(keyword)
                               })
                       }) { cityWeather in
                            VStack(alignment: .leading, spacing: 8) {
                                // 城市標題列 — 點擊後呼叫 tidy_info 並導航至 LocationDetailView
                                Button {
                                    vm.fetchLocationDetail(city: cityWeather.city)
                                } label: {
                                    HStack(alignment: .bottom) {
                                        if let dateStr = cityWeather.weather.first?.startTime,
                                           let startDate = formatDateOnly(dateStr),
                                           let date2Str = cityWeather.weather.last?.endTime,
                                           let endDate = formatDateOnly(date2Str) {
                                            Text(cityWeather.city)
                                                .font(.title2)
                                            Text("\(startDate) -> \(endDate)")
                                                .font(.system(size: 16))
                                        } else {
                                            Text(cityWeather.city)
                                                .font(.title2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.bottom, 4)
                                }
                                .foregroundColor(.primary)

                                ForEach(cityWeather.weather) { info in
                                    WeatherInfoView(info: info)
                                }
                            }
                            .padding()
                        }
                    }
                    .overlay {
                        if vm.isFetchingDetail {
                            ZStack {
                                Color(.systemBackground).opacity(0.55)
                                ProgressView("載入中...")
                                    .padding(20)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                } else {
                    let itemHeight: CGFloat = 120
                    let count = Int(ceil(geo.size.height / itemHeight)) + 1
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(0..<count, id: \.self) { _ in
                            SkeletonWeatherInfoView()
                                .frame(height: itemHeight)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
        }
    }
}

/// 計算非 safeArea 、非 titleBar
private func screenSafeAreaHeight() -> CGFloat {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
        let safeAreaInsets = window.safeAreaInsets
        // 預設 NavigationBar 高度，大部分是 44
        let navigationBarHeight: CGFloat = currentNavigationBarHeight()
        return window.bounds.height - safeAreaInsets.top - safeAreaInsets.bottom - navigationBarHeight - 20
    }
    return UIScreen.main.bounds.height
}

/// 計算目前 navigationBar 高度
private func currentNavigationBarHeight() -> CGFloat {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let nav = window.rootViewController as? UINavigationController else {
        return 44 // fallback -> 通常設置高度
    }
    return nav.navigationBar.frame.height
}

struct CenteredView: View {
    let text: String
    @State private var visibleHeight: CGFloat = 0

    var body: some View {
        // 如何獲取畫面設定數值
        GeometryReader { geo in
            VStack {
                Spacer()
                Text("\(text)\nVisible Height: \(Int(visibleHeight))")
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                visibleHeight = geo.size.height
            }
//            .onChange(of: geo.frame(in: .global)) { oldFrame,frame in
//                if let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//                   let window = screen.windows.first {
//                    let screenHeight = window.frame.height
////                    •    frame.minY 是 View 的上緣座標
////                    •    frame.maxY 是 View 的下緣座標
////                    •    screenHeight 是螢幕的底端座標（通常是 y = 螢幕高）
//                    // 計算交集高度
//                    let visible = max(0, min(frame.maxY, screenHeight) - max(frame.minY, 0))
//                    visibleHeight = visible
//                }
//            }
        }
    }
}

#Preview {
    WeatherView(vm: WeatherLobbyVM())
//        .environmentObject(SettingStore())
}

struct WeatherInfoView: View {
    let info: WeatherInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(formattedTimeRange)")
                .font(.headline)
            
            Text(info.description)
                .font(.subheadline)
            
            HStack {
                Text("溫度：\(info.minTempC)°C - \(info.maxTempC)°C")
                Spacer()
                Text("\(info.comfort)")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var formattedTimeRange: String {
        let start = formatDate(info.startTime)
        let end = formatDate(info.endTime)
        return "\(start) ~ \(end)"
    }

    private func formatDate(_ str: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: str) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return str
    }
}

private func formatDateOnly(_ str: String) -> String? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = formatter.date(from: str) {
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
    return nil
}

struct SkeletonWeatherInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("時間範圍")
                .font(.headline)
                .skeletonize(shapeType: .rectangle(cornerRadius: 0), isActive: true)
            Text("天氣描述")
                .font(.subheadline)
            HStack {
                Text("溫度：--°C - --°C")
                Spacer()
                Text("舒適度")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 2)
        .redacted(reason: .placeholder)
    }
}
