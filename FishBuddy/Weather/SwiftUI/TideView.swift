//
//  TideView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/7/2.
//

import SwiftUI

struct TideListView: View {
    /// ViewModel
    @ObservedObject var vm: WeatherLobbyVM
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TitleBarView(title: "測試", backAction: nil)
                ScrollView {
                    ForEach(0..<100, id: \.self) { index in
                        NavigationLink {
                            TideListView(vm: vm)
                                .ignoresSafeArea() // 這樣寫是 lazy 載入，才不會一次創建一堆實例
                        } label: {
                            HStack(spacing: 8) {
                                Text(randomString(length: 20))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(.black)
                                    .padding(.vertical, 4)
                                    .padding(.leading, 16)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 4)
                                    .padding(.trailing, 8)
                            }
                            .background(.gray)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                }
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).compactMap { _ in letters.randomElement() })
}

struct TitleBarView: View {
    /// 標題
    var title: String
    /// 返回事件
    var backAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            if backAction != nil {
                Button(action: {
                    backAction?()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44, alignment: .center)
            }
            
            Spacer()

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(1)

            Spacer()

            if backAction != nil {
                // 右側預留空間與返回鍵等寬，保持置中對齊
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(Color(.systemGray6))
    }
}

struct TideCityDetailView: View {
    var locationName: String = "Nan’ao Township"
    var dateText: String = "Today, June 12"
    var lunarDate: String = "Lunar date: May 7"
    var tideRange: String = "Tide range: Small"
    var tideData: [TideInfo] = sampleTideData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title bar
            HStack {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .padding(.trailing, 8)
                Text(locationName)
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
            }
            .padding()

            // Date info
            VStack(alignment: .leading, spacing: 4) {
                Text(dateText)
                    .font(.system(size: 18, weight: .semibold))
                Text(lunarDate)
                    .foregroundColor(.gray)
                Text(tideRange)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)

            // Tide cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(tideData) { item in
                    TideCardView(info: item)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

struct TideCardView: View {
    var info: TideInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "wave.3.forward")
                .font(.system(size: 18))
            Text(info.time)
                .font(.system(size: 16, weight: .semibold))
            Text("Above TWVD: \(info.twvd)")
            Text("Above Local MSL: \(info.msl)")
            Text("Above Chart Datum: \(info.chartDatum)")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TideInfo: Identifiable {
    let id = UUID()
    let time: String
    let twvd: String
    let msl: String
    let chartDatum: String
}

// Sample data
let sampleTideData = [
    TideInfo(time: "06:30", twvd: "1.2m", msl: "1.5m", chartDatum: "1.8m"),
    TideInfo(time: "12:45", twvd: "0.2m", msl: "0.5m", chartDatum: "0.8m"),
    TideInfo(time: "18:50", twvd: "1.1m", msl: "1.4m", chartDatum: "1.7m"),
]

#Preview {
    TideListView(vm: WeatherLobbyVM())
}

#Preview {
    TitleBarView(title: "測試")
}

#Preview {
    TideCityDetailView()
}
