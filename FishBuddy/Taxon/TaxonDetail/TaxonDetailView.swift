//
//  TaxonDetailView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/10.
//

import SwiftUI

// MARK: - View
struct TaxonDetailView: View {
    let taxon: Taxon

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                Group {
                    titleBlock
                    section(title: "Overview", text: taxon.overview)
                    if let eco = taxon.ecology, !eco.isEmpty {
                        section(title: "Habitat & Ecology", text: eco)
                    }
                    if let dist = taxon.distribution {
                        DistributionCardView(distribution: dist)
                            .padding(.top, 4)
                    }
                }
                
                footerButtons
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        .contentMargins(.horizontal, 16)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews
    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.secondarySystemBackground))
                .frame(maxWidth: .infinity, maxHeight: 300)
            
            if let url = taxon.heroImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure(_):
                        Image(systemName: "fish")
                            .resizable()
                            .scaledToFit()
                            .padding(40)
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 0))
            } else {
                Image(systemName: "fish")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)
                    .foregroundStyle(.secondary)
            }
        }
        .containerRelativeFrame(.horizontal)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(taxon.commonName)
                    .font(.system(size: 32, weight: .bold))
                if let badge = taxon.conservationBadge {
                    Text(badge)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            Text(taxon.scientificName)
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Label("Favorite", systemImage: "heart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button(action: {}) {
                Label("Map", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button(action: {}) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Distribution Card
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

// MARK: - Preview
#Preview {
    NavigationStack {
        TaxonDetailView(taxon: .demo)
            .padding(.top, 8)
            .navigationTitle("FishBuddy")
    }
}

// MARK: - Demo Data
extension Taxon {
    static let demo: Taxon = {
        let layers: [FishDistributionLayer] = [
            .init(key: "range_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/taxon_ranges/49269/{z}/{x}/{y}.png", minzoom: 0, maxzoom: 19),
            .init(key: "points_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/points/{z}/{x}/{y}.png?taxon_id=49269&verifiable=true", minzoom: 0, maxzoom: 19),
            .init(key: "heatmap_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/heatmap/{z}/{x}/{y}.png?taxon_id=49269&verifiable=true", minzoom: 0, maxzoom: 19)
        ]
        let dist = FishDistribution(type: "tiles", layers: layers, kml_url: "https://www.inaturalist.org/taxa/49269/range.kml", placesSummary: "North Atlantic")
        return Taxon(
            id: 49269,
            commonName: "Atlantic Salmon",
            scientificName: "Salmo salar",
            conservationBadge: "Least Concern",
            heroImageURL: URL(string: "https://images.unsplash.com/photo-1534080564583-6be75777b70a?q=80&w=1200"),
            overview: "The Atlantic salmon is a species of ray-finned fish in the family Salmonidae. It is found in the North Atlantic Ocean and in rivers that flow into the North Atlantic and, due to human introduction, in the Pacific Ocean.",
            ecology: "Atlantic salmon are anadromous fish, migrating from saltwater to freshwater to spawn. They prefer cold, clear, well-oxygenated rivers and streams with gravel or cobble bottoms.",
            distribution: dist
        )
    }()
}
