//
//  WeatherView2.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/4/30.
//

import SwiftUI

struct WeatherView2: View {
    
    @State private var lazyVGridHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 上半部
                ZStack {
                    // 背景
                    VStack {
                        Image("晴天")
                            .resizable()
//                            .aspectRatio(contentMode: .fit)
                            .frame(height: geo.size.height
                                   - lazyVGridHeight
                                   - geo.safeAreaInsets.bottom
                                   )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea(edges: .top)
                        Spacer()
                    }
                    
                    VStack(spacing: 50) {
                        // Title
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text("台北市")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                Text("04-30 ~ 05-01")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                            }
                            Spacer()
                        }

                        VStack {
                            Text("溫度")
                                .font(.system(size: 99, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                            Text("晴天")
                                .font(.system(size: 30, weight: .regular))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }

                        Spacer()
                    }
                    .padding(.bottom, 16)
                    // 高度顯示區塊，置於 ZStack 最上層右上角
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("高度：\(lazyVGridHeight, specifier: "%.1f")")
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)

                        Text("剩餘高：\((geo.size.height - lazyVGridHeight - 64 - geo.safeAreaInsets.bottom), specifier: "%.1f")")
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.blue.opacity(0.5))
                            .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }

                Spacer()
                
                VStack {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),GridItem(.flexible())], spacing: 8) {
                        ForecastCardView(time: "06:00 – 13:00", temp: "22°C – 30°C", note: "鄰近空曠處", color: Color.yellow)
                        ForecastCardView(time: "18:00 – 06:00", temp: "22°C – 27°C", note: "鄰近", color: Color.orange)
                        ForecastCardView(time: "06:00 – 13:00", temp: "22°C – 29°C", note: "鄰近空曠處", color: Color.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        GeometryReader { gridGeo in
                            Color.clear
                                .onAppear {
                                    lazyVGridHeight = gridGeo.size.height + 32 // include Spacer height
                                    let _ = print(lazyVGridHeight)
                                    let remainingHeight = geo.size.height - lazyVGridHeight - 16 - geo.safeAreaInsets.bottom
                                    print("🟢 剩餘高度: \(remainingHeight)")
                                }
                                .onChange(of: gridGeo.size.height) { newValue in
                                    lazyVGridHeight = newValue + 16
                                }
                        }
                    )
                }
            }
        }
    }
    
}

#Preview {
    WeatherView2()
//        .environmentObject(SettingStore())
}

struct ForecastCardView: View {
    var time: String
    var temp: String
    var note: String
    var color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(time)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            Image(systemName: "cloud.sun.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.white)
                .padding(.vertical, 4)

            Text("晴時多雲")
            Text(temp)
            Text(note)
        }
        .font(.system(size: 12))
        .foregroundColor(.white)
        .padding()
        .background(color)
        .cornerRadius(16)
    }
}
