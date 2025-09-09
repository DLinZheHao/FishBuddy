//
//  SkeletonListView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/7/7.
//

import SwiftUI

struct SkeletonListView<Content: View>: View {
    var estimatedItemHeight: CGFloat = 120
    var bodyHeight: CGFloat
    let content: () -> Content

    var body: some View {
        let count = Int(ceil(bodyHeight / estimatedItemHeight)) + 1

        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                content()
                    .skeletonize(isActive: true)
                    .frame(height: estimatedItemHeight)
            }
        }
    }
}

