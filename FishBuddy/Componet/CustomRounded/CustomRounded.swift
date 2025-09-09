//
//  CustomRounded.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/7/4.
//

import SwiftUI

/// 自定義圓角修飾器
struct CustomRounded: ViewModifier {
    /// 左上圓角
    var topLeft: CGFloat = 0
    /// 右上圓角
    var topRight: CGFloat = 0
    /// 左下圓角
    var botLeft: CGFloat = 0
    /// 右下圓角
    var botRight: CGFloat = 0
    /// 邊框顏色
    var borderColor: Color?
    /// 邊框寬度
    var lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .clipShape(CustomRoundedRectangle(topLeft: topLeft, topRight: topRight, bottomLeft: botLeft, bottomRight: botRight))
            .overlay(
                CustomRoundedRectangle(topLeft: topLeft, topRight: topRight, bottomLeft: botLeft, bottomRight: botRight)
                    .stroke(borderColor ?? .pink, lineWidth: lineWidth)
            )
            .background(
                Group {
                    if let borderColor = borderColor {
                        CustomRoundedRectangle(topLeft: topLeft, topRight: topRight, bottomLeft: botLeft, bottomRight: botRight)
                            .fill(borderColor.opacity(0.1))
                    }
                }
            )
    }
}

// 圓角對應的 Shape 實現
struct CustomRoundedRectangle: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = min(min(topLeft, rect.width / 2), rect.height / 2)
        let tr = min(min(topRight, rect.width / 2), rect.height / 2)
        let bl = min(min(bottomLeft, rect.width / 2), rect.height / 2)
        let br = min(min(bottomRight, rect.width / 2), rect.height / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))

        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false)

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)

        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                    radius: bl,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)

        path.closeSubpath()
        return path
    }
}

//#Preview {
//    CustomRounded()
//}
