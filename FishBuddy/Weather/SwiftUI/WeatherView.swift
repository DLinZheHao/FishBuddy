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
                // TODO: 實作 list 重用調整
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
                Text("載入中或無資料")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
}


#Preview {
    WeatherView(vm: WeatherLobbyVM())
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
