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
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea(edges: .top)
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
                }
                .background(Color.blue)
                
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
                                    lazyVGridHeight = gridGeo.size.height  // include Spacer height
                                }
                                .onChange(of: gridGeo.size.height) { newValue in
                                    lazyVGridHeight = newValue
                                }
                        }
                    )
                }
                .background(Color.clear)
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
