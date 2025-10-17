//
//  DistributionCardView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/17.
//

import SwiftUI

struct DistributionCardView: View {
    let distribution: FishDistribution

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Distribution")
                .font(.headline)
            HStack(alignment: .top, spacing: 12) {
                // Snapshot placeholder (real map snapshot can replace this later)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 90)
                    .overlay(
                        Image(systemName: "map")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Distribution Map")
                        .font(.subheadline).bold()
                    if let summary = distribution.placesSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Tap \"Map\" to view heatmap/points/range layers.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        }
    }
}

#Preview {
    // Minimal mock data for preview
    let layers: [FishDistributionLayer] = [
        .init(key: "range_tiles", type: "xyz",
              url: "https://example.com/range/{z}/{x}/{y}.png",
              minzoom: 0, maxzoom: 19),
        .init(key: "points_tiles", type: "xyz",
              url: "https://example.com/points/{z}/{x}/{y}.png",
              minzoom: 0, maxzoom: 19)
    ]
    let mock = FishDistribution(
        type: "tiles",
        layers: layers,
        kml_url: "https://example.com/range.kml",
        placesSummary: "North Atlantic"
    )
    return DistributionCardView(distribution: mock)
}
