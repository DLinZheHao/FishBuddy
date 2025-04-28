//
//  WeatherView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/4/15.
//

import Foundation
import SwiftUI

struct WeatherView: View {
    
    @ObservedObject var vm: WeatherLobbyVM
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("天氣預報")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                Divider()
            }
            
            if let cityData = vm.weatherResponse?.data {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(cityData) { cityWeather in
                        VStack(alignment: .leading, spacing: 8) {
                            if let dateStr = cityWeather.weather.first?.startTime,
                               let startDate = formatDateOnly(dateStr),
                               let date2Str = cityWeather.weather.last?.endTime,
                               let endDate = formatDateOnly(date2Str) {
                                HStack(alignment: .bottom) {
                                    Text("\(cityWeather.city)")
                                        .font(.title2)
                                    Text("\(startDate) -> \(endDate)")
                                        .font(.system(size: 16))
                                }
                                .padding(.bottom, 4)
                            } else {
                                Text(cityWeather.city)
                                    .font(.title2)
                                    .padding(.bottom, 4)
                            }

                            ForEach(cityWeather.weather) { info in
                                WeatherInfoView(info: info)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                // TODO: 實作 Loading 動畫
                VStack {
                    CenteredView(text: "Item \(2)")
                        .frame(minHeight: screenSafeAreaHeight()) // 這裡自動撐到螢幕高度
                                            .background(Color.blue.opacity(0.3))
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// 計算非 safeArea 、非 titleBar 
private func screenSafeAreaHeight() -> CGFloat {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
        let safeAreaInsets = window.safeAreaInsets
        let navigationBarHeight: CGFloat = currentNavigationBarHeight() // 預設 NavigationBar 高度，大部分是 44
        return window.bounds.height - safeAreaInsets.top - safeAreaInsets.bottom - navigationBarHeight - 20
    }
    return UIScreen.main.bounds.height
}

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
            .onChange(of: geo.frame(in: .global)) { frame in
                if let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = screen.windows.first {
                    let screenHeight = window.frame.height
//                    •    frame.minY 是 View 的上緣座標
//                    •    frame.maxY 是 View 的下緣座標
//                    •    screenHeight 是螢幕的底端座標（通常是 y = 螢幕高）
                    // 計算交集高度
                    let visible = max(0, min(frame.maxY, screenHeight) - max(frame.minY, 0))
                    visibleHeight = visible
                }
            }
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
                Text("溫度：\(info.minTemp)°C - \(info.maxTemp)°C")
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
