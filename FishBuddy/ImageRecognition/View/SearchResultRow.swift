//
//  SearchResultRow.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/11/19.
//

import SwiftUI
import Kingfisher

// MARK: - 搜尋結果單列：圖片邊長 = 文字區塊高度
struct SearchResultRow: View {
    let imageURL: URL?
    let title: String
    let idText: String
    let scoreText: String

    @State private var textHeight: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            KFImage(imageURL)
                .placeholder { ProgressView() }
                .cancelOnDisappear(true)
                .resizable()
                .scaledToFill()
                .frame(width: max(textHeight, 1), height: max(textHeight, 1)) // 正方形，避免初始 0 尺吋
                .clipped()
                .cornerRadius(8)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text(idText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(scoreText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            // 量測 VStack 的實際高度
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: TextHeightPreferenceKey.self, value: proxy.size.height)
                }
            )

            Spacer()
        }
        .onPreferenceChange(TextHeightPreferenceKey.self) { h in
            // 更新圖片邊長
            textHeight = h
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.1)))
    }
}

private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
