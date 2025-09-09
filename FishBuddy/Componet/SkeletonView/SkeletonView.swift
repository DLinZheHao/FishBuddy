//
//  SkeletonView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/7/4.
//

import SwiftUI

/// 骨架的形狀類型
public enum SkeletonShape {
    /// 矩形（可設定圓角）
    case rectangle
    /// 圓形（通常用於頭像、icon）
    case circle
    /// 膠囊形狀（常見於文字區塊或按鈕佔位）
    case capsule
}

/// 可以自己選擇形狀的骨架視圖
struct SkeletonView: View {
    /// 骨架的形狀
    var shape: SkeletonShape?
    /// 圓角半徑
    var cornerRadius: CGFloat = 8
    /// 輸入的大小
    var size: CGSize?

    var body: some View {
        let shape = shape ?? .rectangle
        switch shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(white: 0.92))
                .frame(width: size?.width, height: size?.height ?? 20)
                .shimmering()
        case .circle:
            Circle()
                .fill(Color(white: 0.92))
                .frame(width: size?.width, height: size?.height ?? 20)
                .shimmering()
        case .capsule:
            Capsule()
                .fill(Color(white: 0.92))
                .frame(width: size?.width, height: size?.height ?? 20)
                .shimmering()
        }

    }
}

/// 提供閃爍動畫效果的 ViewModifier，用於骨架畫面
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let width = geometry.size.width

                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width / 2)
                    //                .rotationEffect(.degrees(30))
                    // 這裡的 offset 計算是為了讓閃爍的亮光從左邊畫面外滑入，
                    // 透過 phase 狀態控制位置，範圍從 -1 到 1.5，
                    // 寬度則是整個骨架寬度加上亮光本身寬度（width + width/2），
                    // 確保亮光完全滑過骨架視圖並滑出右邊畫面外，呈現流暢閃爍效果。
                    .offset(x: phase * (width + width / 2))
                    
                }
                // 使用混合模式讓亮光漸層與下方骨架背景融合，避免死白遮蓋
                // 可以想像顏料混合那樣
                .blendMode(.overlay)
                .mask(content) // <<== 這裡：把亮光裁切成 content 的形狀
            )
            .onAppear {
                // 設定無限動畫，這個 func 會自動處理 phase 的值回歸原本的狀態，好執行動畫
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - 捕捉原始元件大小

/// 用來擷取 View 實際大小的 PreferenceKey
/// - 使用 GeometryReader 搭配此 key 可讓我們取得元件的寬高資訊
private struct SizePreferenceKey: PreferenceKey {
    // defaultValue 和 reduce 是實作 PreferenceKey 協定（protocol）時的必要成員
    /// 初始值為 nil，表示尚未取得大小
    static var defaultValue: CGSize? = nil

    /// 每次取得新值時，直接用最新的尺寸覆蓋（只取最後一次大小）
    static func reduce(value: inout CGSize?, nextValue: () -> CGSize?) {
        if let next = nextValue() {
            value = next
        }
    }
}

/// View 的自定義 Modifier：在 loading 狀態下顯示骨架載入畫面
struct SkeletonizeModifier: ViewModifier {
    /// 控制是否顯示骨架
    let isActive: Bool
    /// 控制自定義形狀
    var shape: SkeletonShape?
    /// 儲存原始 View 尺寸
    @State private var size: CGSize? = nil

    func body(content: Content) -> some View {
        ZStack {
            if isActive {
                // 顯示 SkeletonView，使用原始內容尺寸
                SkeletonView(shape: shape, size: size)
                    .transition(.opacity)
            } else {
                // 顯示原始內容，並透過 GeometryReader 擷取其尺寸
                content
                    .background(
                        GeometryReader { geo in
                            // 用來量尺寸用的
                            Color.clear
                                .preference(key: SizePreferenceKey.self, value: geo.size)
                        }
                    )
            }
        }
        // 當尺寸變化時，更新 state
        .onPreferenceChange(SizePreferenceKey.self) { value in
            if let value {
                self.size = value
            }
        }
    }
}

struct SkeletonGroupModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .redacted(reason: isActive ? .placeholder : [])
            .skeletonize(isActive: isActive)
    }
}

extension View {
    func skeletonizeGroup(isActive: Bool) -> some View {
        self.modifier(SkeletonGroupModifier(isActive: isActive))
    }
}

// MARK: - Demo View

/// 展示骨架效果的範例畫面
struct DemoSkeletonView: View {
    /// 是否顯示骨架動畫
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 圓形 skeleton（模擬 avatar）
            HStack {
                SkeletonView(shape: .circle, size: CGSize(width: 60, height: 60))
                VStack(alignment: .leading) {
                    // 文字長條骨架
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 20)
                        .shimmering()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 16)
                        .shimmering()
                }
            }

            Divider()

            // 自動大小捕捉示範
            VStack(alignment: .leading, spacing: 12) {
                Text("這是一段模擬的標題文字")
                    .font(.headline)
                    .skeletonize(isActive: isLoading) // 根據 isLoading 自動轉換成骨架

                Text("這段是比較長的副標題內容，會根據實際文字自動產生骨架寬度")
                    .font(.subheadline)
                    .skeletonize(isActive: isLoading)
            }
            

            // 切換載入狀態的按鈕
            Button(isLoading ? "載入中..." : "重新載入") {
                isLoading.toggle()
            }
            .padding(.top, 20)
        }
        .padding()
        .animation(.default, value: isLoading)
    }
}

#Preview {
    DemoSkeletonView()
}

