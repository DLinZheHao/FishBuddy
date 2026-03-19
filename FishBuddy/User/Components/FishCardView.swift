//
//  FishCardView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct FishCardView: View {
    let title: String
        let subtitle: String
        let imageName: String

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: imageName)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
}

#Preview {
    FishCardView(title: "test fish",
                 subtitle: "test subtitle",
                 imageName: "...")
}
