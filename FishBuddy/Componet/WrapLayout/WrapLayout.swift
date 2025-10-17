//
//  WrapLayout.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/17.
//

import SwiftUI

/// 只是個小封裝。它提供一個簡單的 View 介面（帶 spacing/runSpacing），內部直接用 FlowLayout 這個自訂 Layout 來排版
/// 可以當成一台手機
struct WrapLayout<Content: View>: View {
    let spacing: CGFloat
    let runSpacing: CGFloat
    @ViewBuilder let content: Content
    
    init(spacing: CGFloat = 8, runSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.runSpacing = runSpacing
        self.content = content()
    }
    
    var body: some View {
        FlowLayout(spacing: spacing, runSpacing: runSpacing) { content }
    }
}

/// 真正做事的地方。它實作 SwiftUI 的 Layout protocol，做「像 HTML inline-wrap 一樣」的貪婪式換行排列（左到右塞滿再換下一行）
/// 可以當成手機得到的「內部」零件，這樣 WrapLayout 就可以當成手機的外殼
/// Very lightweight flow layout using the new layout protocol when available; fallback otherwise.
struct FlowLayout: Layout {
    /// 水平間距
    var spacing: CGFloat = 8
    /// 換行之後，兩行（row）之間的 垂直距離
    var runSpacing: CGFloat = 8
    
    struct Cache {
        var sizes: [CGSize] = []
    }

    // cache 就是讓你存放「計算過的中間結果」，以便在 量測階段（sizeThatFits）和 擺放階段（placeSubviews）之間重複使用，減少重複運算。
    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: Array(repeating: .zero, count: subviews.count))
    }
    
    /// 可以想成 tagLineView 換行的邏輯
    /// 試算大小、嘗試擺放：目的是告訴父容器：「我大概要多少寬高」，這個階段不會真的畫 UI，只是在推算位置和總尺寸
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? .infinity // 需要給一個預測的寬度，否算可能失效
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            if i < cache.sizes.count {
                cache.sizes[i] = size
            }
            if x + size.width > width {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }
    
    /// 正式計算，把每個 subview 擺到正確位置
    ///  bounds 是實際計算的範圍，proposal 是預估的大小（可能是無限大）
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for (i, subview) in subviews.enumerated() {
            let size: CGSize
            if i < cache.sizes.count {
                size = cache.sizes[i]
            } else {
                size = subview.sizeThatFits(.unspecified)
            }
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ScrollView {
        WrapLayout(spacing: 8, runSpacing: 10) {
            ForEach(["Fusiform", "Compressed", "Elongated", "Striped", "Spotted", "Solid", "Large Mouth", "Small Mouth", "Sharp Teeth", "Freshwater", "Saltwater", "Brackish"], id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(Color.blue.opacity(0.9))
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
}

