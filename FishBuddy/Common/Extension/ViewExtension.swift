//
//  ViewExtension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/7/4.
//

import SwiftUI

// 自定義圓角矩形
public extension View {
    func customRounded(topLeft: CGFloat = 0,
                       topRight: CGFloat = 0,
                       bottomLeft: CGFloat = 0,
                       bottomRight: CGFloat = 0,
                       borderColor: Color? = nil,
                       lineWidth: CGFloat = 0) -> some View {
        self.modifier(CustomRounded(topLeft: topLeft, topRight: topRight, botLeft: bottomLeft, botRight: bottomRight, borderColor: borderColor,
                                    lineWidth: lineWidth))
    }
}

// 骨架效果
public extension View {
    /// 根據 isActive 狀態切換成骨架載入畫面
    func skeletonize(shapeType: SkeletonShape? = nil, isActive: Bool) -> some View {
        modifier(SkeletonizeModifier(isActive: isActive, shape: shapeType))
    }
    
    /// 為 View 套用閃爍效果
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}
