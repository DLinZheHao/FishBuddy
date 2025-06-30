//
//  WeatherView2.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/4/30.
//

import SwiftUI

struct WeatherView2: View {
        
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 上半部
                ZStack {
                    // 背景
                    VStack {
                        AnimatedImageFromFramesView()
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
                }
                .background(Color.clear)
            }
        }
    }
    
}

// 試驗版 gif 型圖片動畫
struct AnimatedImageFromFramesView: View {
    @State private var currentFrameIndex = 0
    private let frames: [UIImage] = (0..<3).compactMap { UIImage(named: "animated_landscape_loop_\($0)") }
    private let frameDuration = 0.3  // Total duration 10s / 5 frames = 2s per frame

    var body: some View {
        if !frames.isEmpty {
            Image(uiImage: frames[currentFrameIndex])
                .resizable()
                .ignoresSafeArea(edges: .top)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { _ in
                        currentFrameIndex = (currentFrameIndex + 1) % frames.count
                    }
                }
        } else {
            Color.black
        }
    }
}

// 圖片載入器
struct AnimatedImageLoader {
    static func load() -> UIImage? {
        var frames: [UIImage] = []

        // 這裡假設你有 5 張圖片（依你的 GIF）
        for i in 0..<5 {
            if let image = UIImage(named: "animated_landscape_loop_\(i)") {
                frames.append(image)
            }
        }

        // 將所有幀合成動畫，播放總時間為 10 秒
        return UIImage.animatedImage(with: frames, duration: 0.01)
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

/*
 Lazy Grid 對照表：
 
 +----------------+----------------+--------------+----------------------+
 |     元件       |  整體排列方向   |  捲動方向     | 每一列的排列方向       |
 +----------------+----------------+--------------+----------------------+
 | LazyVGrid      | 垂直（上下）     | 垂直捲動      | 水平（左右）           |
 | LazyHGrid      | 水平（左右）     | 水平捲動      | 垂直（上下）           |
 +----------------+----------------+--------------+----------------------+
 
 使用建議：
 - LazyVGrid：常用於列表或卡片向下捲動的 UI。
 - LazyHGrid：常用於橫向滑動的卡片排版。
*/
