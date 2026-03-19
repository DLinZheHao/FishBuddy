//
//  FeatureCard.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct FeatureCard: View {
    let title: String
    let systemImage: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 45, height: 45)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Text(title)
                    .font(.iOS_font12())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .frame(width: 76)
    }
}

struct FeatureSection: View {
    var body: some View {
        VStack {
            HStack {
                FeatureCard(
                    title: "Photo Gallery",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }
}

#Preview {
    FeatureCard(title: "Photo Gallery",
                systemImage: "photo.on.rectangle")
}
