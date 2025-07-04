//
//  SkeletonView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/7/4.
//

import SwiftUI

/// 骨架的形狀類型
enum SkeletonShape {
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
    var shape: SkeletonShape = .rectangle
    /// 圓角半徑
    var cornerRadius: CGFloat = 8
    /// 輸入的大小
    var size: CGSize?

    var body: some View {
        switch shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size?.width, height: size?.height ?? 20)
                .shimmering()
        case .circle:
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size?.width, height: size?.height ?? 20)
                .shimmering()
        case .capsule:
            Capsule()
                .fill(Color.gray.opacity(0.3))
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
                // 套上線性漸層作為閃爍效果的遮罩
                LinearGradient(
                    gradient: Gradient(colors: [
                        .gray.opacity(0.3),
                        .gray.opacity(0.1),
                        .gray.opacity(0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 300) // 動態偏移造成閃爍感
                .blendMode(.overlay)
                .mask(content)
            )
            .onAppear {
                // 設定無限動畫
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    /// 為 View 套用閃爍效果
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }

    /// 根據 isActive 狀態切換成骨架載入畫面
    func skeletonize(isActive: Bool) -> some View {
        modifier(SkeletonizeModifier(isActive: isActive))
    }
}

// MARK: - 捕捉原始元件大小

/// 用來擷取 View 實際大小的 PreferenceKey
/// - 使用 GeometryReader 搭配此 key 可讓我們取得元件的寬高資訊
private struct SizePreferenceKey: PreferenceKey {
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
private struct SkeletonizeModifier: ViewModifier {
    /// 控制是否顯示骨架
    let isActive: Bool
    /// 儲存原始 View 尺寸
    @State private var size: CGSize? = nil

    func body(content: Content) -> some View {
        ZStack {
            if isActive {
                // 顯示 SkeletonView，使用原始內容尺寸
                SkeletonView(size: size)
                    .transition(.opacity)
            } else {
                // 顯示原始內容，並透過 GeometryReader 擷取其尺寸
                content
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: SizePreferenceKey.self, value: geo.size)
                        }
                    )
            }
        }
        // 當尺寸變化時，更新 state
        .onPreferenceChange(SizePreferenceKey.self) { value in
            self.size = value
        }
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
