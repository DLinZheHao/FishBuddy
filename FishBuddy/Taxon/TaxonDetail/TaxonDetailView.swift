//
//  TaxonDetailView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/10.
//

import SwiftUI

// MARK: - View
struct TaxonDetailView: View {
    let taxon: TaxonItem
    @State private var showDistribution = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 圖片顯示器
                hero
                Group {
                    // 標題區塊
                    titleBlock
                        .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // 生物提示詞
                    if let prompts = taxon.userPrompt, !prompts.isEmpty {
                        UserPromptView(prompt: prompts)
                            .padding(.horizontal, 16)
                    }
                    
                    if let wikipedia = taxon.meta?.wikipedia {
                        // 概述區塊
                        if let extract = wikipedia.extract {
                            section(title: "概述", text: extract)
                                .padding(.horizontal, 16)
                        }
                        // 敘述區塊
                        if let description = wikipedia.sections?.description, !description.isEmpty {
                            section(title: "敘述", text: description)
                                .padding(.horizontal, 16)
                        }
                        // 生態區塊
                        if let ecology = wikipedia.sections?.ecology, !ecology.isEmpty {
                            section(title: "生態", text: ecology)
                                .padding(.horizontal, 16)
                        }
                        // 經濟利用區塊
                        if let economicUse = wikipedia.sections?.economicUse, !economicUse.isEmpty {
                            section(title: "經濟利用", text: economicUse)
                                .padding(.horizontal, 16)
                        }
                    }
                   
                }
                // 功能按鍵
                footerButtons
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .coordinateSpace(name: "taxonScroll")
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.container, edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDistribution) {
            TaxonDistributionView(taxonId: taxon.taxonId)
                .navigationTitle("地圖")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Subviews
    private var hero: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("taxonScroll")).minY
            // Base height for the hero image
            let baseHeight: CGFloat = 300
            // When pulling down (minY > 0), increase height by minY
            let dynamicHeight = max(baseHeight, baseHeight + (minY > 0 ? minY : 0))

            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.secondarySystemBackground))
                    .frame(maxWidth: .infinity, minHeight: dynamicHeight, maxHeight: dynamicHeight)

                if let photos = taxon.photos, !photos.isEmpty  {
                    let images: [ImageData] = photos.compactMap { photo in
                        guard let url = URL(string: photo.url) else { return nil }
                        return ImageData(image: url, description: photo.attribution)
                    }
                    ImageInspectorView(images: images)
                        .frame(maxWidth: .infinity, minHeight: dynamicHeight, maxHeight: dynamicHeight)
                        .clipped()
                } else {
                    Image(systemName: "fish")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: dynamicHeight, alignment: .center)
            // Pin the top edge so the view expands upward when pulling down
            .offset(y: minY > 0 ? -minY : 0)
        }
        // Important: the outer GeometryReader needs a fixed baseline height
        .frame(height: 300)
        .contentShape(Rectangle())
    }
    
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(taxon.commonName ?? "")
                    .font(.system(size: 32, weight: .bold))
//                if let badge = taxon.conservationBadge {
//                    Text(badge)
//                        .font(.caption)
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 4)
//                        .background(Color(.systemGray6))
//                        .clipShape(Capsule())
//                }
            }
            Text(taxon.scientificName ?? "")
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading) // 讓卡片撐滿可用寬度
        .background(
            ZStack(alignment: .top) {
                // Bottom-only "shadow" using a gradient strip (top -> clear)
                
                // Card surface
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.98)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.00),
                            Color.black.opacity(0.07)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                    .offset(y: 4)
                    .mask(
                        RoundedRectangle(cornerRadius: 0, style: .continuous)
                            .customRounded(
                                bottomLeft: 12,
                                bottomRight: 12,
                                lineWidth: 0)
                    )
                    .allowsHitTesting(false)
                }
            }
        )
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Label("Favorite", systemImage: "heart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            // 分布地區區塊
            if taxon.distributionLayers != nil {
                Button(action: {
                    showDistribution = true
                }) {
                    Label("Map", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button(action: {}) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Preview mock + preview
#if DEBUG
private extension TaxonItem {
    static var previewMock: TaxonItem {
        let photos: [Photo] = [
            Photo(url: "https://images.unsplash.com/photo-1534080564583-6be75777b70a?q=80&w=1200",
                  licenseCode: "CC-BY",
                  attribution: "Photo by Unsplash",
                  source: "unsplash"),
            Photo(url: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?q=80&w=1200",
                  licenseCode: "CC-BY",
                  attribution: "Photo by Unsplash",
                  source: "unsplash"),
            Photo(url: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?q=80&w=1200",
                  licenseCode: "CC-BY",
                  attribution: "Photo by Unsplash",
                  source: "unsplash")
        ]

        let sections = Sections(
            distribution: "分布於北大西洋與入海河川，因人為引進亦見於太平洋部分區域。",
            description: "體型流線，背部呈藍綠色且具黑色斑點，腹部銀白，成魚遷徙回淡水產卵。",
            ecology: "遷徙性魚類，偏好冷且含氧量高的河川。幼魚在淡水成長，成魚回海洋覓食。",
            economicUse: "具高經濟價值，為重要食用魚與養殖物種。"
        )

        let wiki = WikipediaMeta(
            title: "Atlantic salmon",
            canonicalTitle: "Salmo salar",
            extract: "大西洋鮭是一種鮭科溯河性魚類，原生於北大西洋及其入海河川，部分族群會進行長距離洄游。",
            url: "https://zh.wikipedia.org/wiki/%E5%A4%A7%E8%A5%BF%E6%B4%8B%E9%AE%AD",
            lang: "zh",
            variant: nil,
            query: nil,
            strategy: nil,
            sections: sections
        )

        let meta = Meta(wikipedia: wiki)

        // Distribution mocks used by DistributionCardView (converted type)
        let layers: [FishDistributionLayer] = [
            .init(key: "range_tiles", type: "xyz",
                  url: "https://api.inaturalist.org/v1/taxon_ranges/49269/{z}/{x}/{y}.png",
                  minzoom: 0, maxzoom: 19),
            .init(key: "points_tiles", type: "xyz",
                  url: "https://api.inaturalist.org/v1/points/{z}/{x}/{y}.png?taxon_id=49269&verifiable=true",
                  minzoom: 0, maxzoom: 19),
            .init(key: "heatmap_tiles", type: "xyz",
                  url: "https://api.inaturalist.org/v1/heatmap/{z}/{x}/{y}.png?taxon_id=49269&verifiable=true",
                  minzoom: 0, maxzoom: 19)
        ]
        let fishDist = FishDistribution(type: "tiles", layers: layers, kml_url: "https://www.inaturalist.org/taxa/49269/range.kml", placesSummary: "North Atlantic")

        // Build TaxonItem mock
        return TaxonItem(
            taxonId: 49269,
            scientificName: "Salmo salar",
            commonName: "大西洋鮭",
            slug: "atlantic-salmon",
            photos: photos,
            meta: meta,
            embedding: [],
            textEmbedding: [],
            embeddingMeta: nil,
            distribution: Distribution(type: "tiles", kmlURL: "https://www.inaturalist.org/taxa/49269/range.kml"),
            distributionLayers: [
                DistributionLayer(layerKey: "range_tiles", type: "xyz",
                                  url: "https://api.inaturalist.org/v1/taxon_ranges/49269/{z}/{x}/{y}.png",
                                  minzoom: 0, maxzoom: 19),
                DistributionLayer(layerKey: "points_tiles", type: "xyz",
                                  url: "https://api.inaturalist.org/v1/points/{z}/{x}/{y}.png?taxon_id=49269&verifiable=true",
                                  minzoom: 0, maxzoom: 19)
            ], userPrompt:  UserPrompt(
                morphology: ["Fusiform", "Compressed", "Elongated"],
                pattern: ["Striped", "Spotted", "Solid"],
                traits: ["Large Mouth", "Small Mouth", "Sharp Teeth"],
                habitat: ["Freshwater", "Saltwater", "Brackish"]
            )
        )
    }
}

#Preview {
    NavigationStack {
        TaxonDetailView(taxon: .previewMock)
            .navigationTitle("FishBuddy")
    }
}
#endif
