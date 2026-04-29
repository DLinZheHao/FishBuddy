//
//  TaxonDetailView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/10.
//

import SwiftUI

// MARK: - View
struct TaxonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isFavorited: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var selectedTab: SpeciesTab = .overview
    @State private var showSpeciesDigestDebug: Bool = false
    
    let taxon: TaxonItem
    let sessionID: Int64?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // image viewer
                        hero
                            
                        Group {
                            // 標題區塊
                            SpeciesInfoHeader(titleZh: taxon.commonNameZh ?? "",
                                              scientificName: taxon.scientificName,
                                              chips: [])
                            .padding(.horizontal, 16)
                            
                            
                            QuickStatsRow(items: taxon.makeQuickStats())
                            
                            Divider()
                            
                            VStack(spacing: 4) {
                                // Tabs
                                SpeciesTabBar(selected: $selectedTab)
                                    .padding(.horizontal, 16)
                                
                                SpeciesTabsPager(taxonItem: taxon, selected: $selectedTab)
                            }
                            
                        }
                    }
                    .padding(.bottom, 24)
                    .background(Color.appBackground)
                }
                .coordinateSpace(name: "taxonScroll")
                .scrollIndicators(.hidden)
                .ignoresSafeArea(.container, edges: .top)
                .navigationBarTitleDisplayMode(.inline)
                
                // Overlay navigation buttons
                HStack(spacing: 12) {
                    CircleIconButton(systemName: "chevron.left") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    CircleIconButton(systemName: isFavorited ? "heart.fill" : "heart") {
                        Task {
                            isFavorited.toggle()
                            do {
                                if isFavorited {
                                    try await UserStore.shared.addFavorite(taxonID: taxon.taxonId)
                                } else {
                                    try await UserStore.shared.removeFavorite(taxonID: taxon.taxonId)
                                }
                            } catch {
                                // Revert UI state on failure
                                isFavorited.toggle()
                            }
                        }
                    }
                    
                    CircleIconButton(systemName: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                    
                    if #available(iOS 26.0, *) {
                        CircleIconButton(systemName: "square.and.arrow.down") {
                            showSpeciesDigestDebug = true
                        }
                    }
                }
                .padding(.horizontal, 16)
#if DEBUG
                .sheet(isPresented: $showSpeciesDigestDebug) {
                    if #available(iOS 26.0, *) {
                        SpeciesDigestDebugView(
                            vm: SpeciesDigestViewModel(taxon: taxon)
                        )
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                    }
                }
#endif
//                .padding(.top, safeAreaTopInset()) // 讓按鈕不會卡到瀏海
            }
            .toolbar(.hidden, for: .navigationBar) // Replace the system navigation bar with a custom overlay
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: ["FishBuddy - Species Detail"])
            }
            .onAppear {
                Task {
                    do {
                        isFavorited = try await UserStore.shared.isFavorite(taxonID: taxon.taxonId)
                    } catch {
                        isFavorited = false
                    }
                    
                    if let sessionID {
                        do {
                            try await UserStore.shared.logTaxonView(taxonID: taxon.taxonId, sessionID: sessionID)
                            print("user store log taxon view success")
                        } catch {
                            print("user store log taxon view error: \(error)")
                        }                        
                    }
                }
            }
        }
        .background(Color.appBackground)
    }
    
    /// 取得安全區上方 inset（簡單穩定，避免按鈕頂到瀏海）
    private func safeAreaTopInset() -> CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?
            .safeAreaInsets.top ?? 0
    }
    
    // MARK: - Subviews
    private var hero: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("taxonScroll")).minY
            // Base height for the hero image
            let baseHeight: CGFloat = 360
            // When pulling down (minY > 0), increase height by minY
            let dynamicHeight = max(baseHeight, baseHeight + (minY > 0 ? minY : 0))

            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.secondarySystemBackground))
                    .frame(maxWidth: .infinity, minHeight: dynamicHeight, maxHeight: dynamicHeight)

                /*
                For now, we’ll skip the photo license filtering logic and display all images uniformly.
                We’ll refine this before release.
                */
                
                let unifiedPhotos: [UnifiedPhoto] =
                taxon.photos.compactMap { $0.toUnifiedPhoto() } +
                taxon.wikiPhotos.compactMap { $0.toUnifiedPhoto() }
                
                if !unifiedPhotos.isEmpty  {
                    let images: [ImageData] = unifiedPhotos.compactMap { photo in
                        let url = photo.url
                        return ImageData(image: url, description: "")
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
        .frame(height: 360)
        .contentShape(Rectangle())
    }
    
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(taxon.commonNameZh ?? "")
                    .font(.system(size: 32, weight: .bold))
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

// MARK: - Preview mock + preview
#if DEBUG
extension TaxonItem {
    static var previewMock: TaxonItem {
        // photos -> [ResolvedPhoto] with idx
        let resolvedPhotos: [ResolvedPhoto] = [
            ResolvedPhoto(idx: 0, url: "https://inaturalist-open-data.s3.amazonaws.com/photos/11343489/large.jpg", licenseCode: "cc-by-nc", attribution: "(c) tamsynmann, some rights reserved (CC BY-NC), uploaded by tamsynmann", source: "taxon_gallery"),
            ResolvedPhoto(idx: 1, url: "https://inaturalist-open-data.s3.amazonaws.com/photos/60888836/large.jpeg", licenseCode: "cc-by", attribution: "(c) Dan Schofield, some rights reserved (CC BY), uploaded by Dan Schofield", source: "taxon_gallery"),
            ResolvedPhoto(idx: 2, url: "https://inaturalist-open-data.s3.amazonaws.com/photos/17975566/large.jpeg", licenseCode: "cc-by-nc", attribution: "(c) Kelly-Anne Masterman, some rights reserved (CC BY-NC), uploaded by Kelly-Anne Masterman", source: "taxon_gallery"),
            ResolvedPhoto(idx: 3, url: "https://inaturalist-open-data.s3.amazonaws.com/photos/67712/large.jpg", licenseCode: "cc-by", attribution: "(c) Silke Baron, some rights reserved (CC BY)", source: "taxon_gallery"),
            ResolvedPhoto(idx: 4, url: "https://inaturalist-open-data.s3.amazonaws.com/photos/67713/large.jpg", licenseCode: "cc-by", attribution: "(c) Silke Baron, some rights reserved (CC BY)", source: "taxon_gallery"),
            ResolvedPhoto(idx: 5, url: "https://static.inaturalist.org/photos/121071180/large.jpg", licenseCode: nil, attribution: nil, source: "taxon_default"),
            ResolvedPhoto(idx: 6, url: "https://inaturalist-open-data.s3.amazonaws.com/photos/67714/large.jpg", licenseCode: "cc-by-nc-nd", attribution: "(c) Markus Fritze, some rights reserved (CC BY-NC-ND)", source: "taxon_gallery_any_license")
        ]

        // distribution (raw) + flattened distributionLayers -> [ResolvedDistributionLayer]
        let distribution = Distribution(
            type: "tiles",
            layers: [
                DistributionLayer(layerKey: "range_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/taxon_ranges/121261/{z}/{x}/{y}.png", minzoom: 0, maxzoom: 19),
                DistributionLayer(layerKey: "places_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/taxon_places/121261/{z}/{x}/{y}.png", minzoom: 0, maxzoom: 19),
                DistributionLayer(layerKey: "points_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/points/{z}/{x}/{y}.png?taxon_id=121261&verifiable=true", minzoom: 0, maxzoom: 19),
                DistributionLayer(layerKey: "heatmap_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/heatmap/{z}/{x}/{y}.png?taxon_id=121261&verifiable=true", minzoom: 0, maxzoom: 19)
            ],
            kmlURL: "https://www.inaturalist.org/taxa/121261/range.kml",
            places: []
        )

        let resolvedLayers: [ResolvedDistributionLayer] = [
            ResolvedDistributionLayer(idx: 0, layerKey: "range_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/taxon_ranges/121261/{z}/{x}/{y}.png", minZoom: 0, maxZoom: 19),
            ResolvedDistributionLayer(idx: 1, layerKey: "places_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/taxon_places/121261/{z}/{x}/{y}.png", minZoom: 0, maxZoom: 19),
            ResolvedDistributionLayer(idx: 2, layerKey: "points_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/points/{z}/{x}/{y}.png?taxon_id=121261&verifiable=true", minZoom: 0, maxZoom: 19),
            ResolvedDistributionLayer(idx: 3, layerKey: "heatmap_tiles", type: "xyz", url: "https://api.inaturalist.org/v1/heatmap/{z}/{x}/{y}.png?taxon_id=121261&verifiable=true", minZoom: 0, maxZoom: 19)
        ]

        // taxonomy
        let taxonomy = Taxonomy(phylum: "Chordata",
                                classType: "Actinopterygii",
                                order: "Scorpaeniformes",
                                family: "Tetrarogidae",
                                genus: "Ablabys")

        // basic info
        let basicInfo = BasicInfo(summary: "Ablabys taenianotus 為小型底棲硬骨魚，屬於毒棘鮋類群（Scorpaeniformes），分布於印度-西太平洋範圍的熱帶至亞熱帶淺海區。此種外型具高度隱蔽性，習於底部偽裝以伏擊獵物。")

        // morphology
        let morphology = Morphology(
            bodyShape: "體型側扁並略呈葉片狀，身體短且高度壓扁，能貼附底質以隱匿身形。",
            colorationAndPattern: "體色與底質或枯葉相近，通常呈褐色、灰褐或紅褐等變異色調，以利偽裝，具不規則斑紋或斑點。",
            finsAndSpecialFeatures: "頭部及體側具棘突或皮瓣用以破碎輪廓，背鰭自頭頂延伸至尾柄，前段棘條可豎立成如鳳頭般的鰭冠，背鰭棘具毒腺，胸鰭發達，可支撐伏臥姿勢與短距離移動。"
        )

        // habitat and distribution
        let habitatAndDistribution = HabitatAndDistribution(
            globalDistribution: "分布於東印度洋至西太平洋熱帶至亞熱帶海域，自安達曼海、東南亞一路到斐濟，北至日本，南至澳洲等地的沿岸淺海。",
            localHabitatType: "偏好礁區邊緣、砂礫底、泥砂混合底及海草床等環境，常棲息於有碎石、枯葉或藻類覆蓋的底質，利用環境結構隱蔽身形。"
        )

        // environment and depth
        let environmentAndDepth = EnvironmentAndDepth(
            environment: "底棲性，與礁石、砂底、海草床及藻類覆蓋區密切相關，屬近岸淺海生境的一員。",
            depthRangeM: "約 1–78 公尺"
        )

        // ecology and behavior
        let ecologyAndBehavior = EcologyAndBehavior(
            generalEcology: "為伏擊性掠食者，利用偽裝等待小型甲壳類與小魚靠近後快速捕食，生態位屬於近底層肉食者。",
            socialStructure: "多獨居或成對出現，活動範圍小，個體通常零散分布於適合的隱蔽底質上。",
            dailyRhythm: "主要為夜行性，白天多半靜止伏臥於底質偽裝成枯葉或漂浮碎屑，夜間較為活躍覓食。"
        )

        // growth and life history
        let growthAndLifeHistory = GrowthAndLifeHistory(
            maximumLengthCm: "15",
            growthNotes: "屬小型底棲魚類，成體體長多落在數公分至十餘公分範圍，成長速率與年齡結構資料有限，待補充。",
            lifeHistoryNotes: "壽命與完整生活史研究有限，推測與多數近岸底棲小型掠食魚類相似，早期生活史可能與沿岸淺海環境緊密相關，詳細資料有限，待補充。"
        )

        // conservation and human uses
        let conservationAndHumanUses = ConservationAndHumanUses(
            conservationStatus: "IUCN 評估為無危（Least Concern, LC）。",
            threats: "目前未被列為特別瀕危物種，主要潛在威脅來自沿岸棲地劣化、污染及過度開發等對珊瑚礁與淺海環境的影響。",
            managementOrProtection: "未有專門管理措施，多仰賴一般性沿岸及珊瑚礁生態系保育措施；持續監測棲地狀況與漁業壓力有助於維持族群穩定。"
        )

        // taiwan and regional notes
        let taiwanAndRegionalNotes = TaiwanAndRegionalNotes(
            taiwanDistribution: "台灣周邊沿岸及珊瑚礁區有分布紀錄，可能零星棲息於適合之砂礫底或礁區邊緣，但族群量與長期變化仍缺乏系統性調查。",
            regionalEcologicalRole: "在區域珊瑚礁與近岸生境中擔任小型底棲掠食者的角色，透過攝食小型甲殼類與魚類，參與底棲食物網並協助調節小型無脊椎動物與魚類族群結構。"
        )

        // reproduction
        let reproduction = Reproduction(
            reproductiveMode: "具體繁殖模式與產卵型態研究有限，待補充。",
            spawningBehavior: "有研究指出其在日本周邊會出現特定繁殖季節與社會行為，但細節尚未廣泛量化，整體資料有限，待補充。",
            parentalCare: "是否具明顯親代照護行為尚缺乏明確研究證據，資料有限，待補充。"
        )

        // diet and behavior
        let dietAndBehavior = DietAndBehavior(
            diet: "以小型甲殼類（如小蝦等）及小型魚類為主的肉食性飲食結構，屬近底層伏擊掠食者。",
            foragingBehavior: "採用偽裝伏擊策略，常偽裝成枯葉或漂浮碎屑，隨水流輕微搖晃，等待獵物接近後突然出擊吞食。"
        )

        // wiki photos -> [ResolvedWikiPhoto]
        let wikiPhotos: [ResolvedWikiPhoto] = [
            ResolvedWikiPhoto(
                idx: 0,
                url: "https://upload.wikimedia.org/wikipedia/commons/e/e1/Ablabys_taenianotus_by_Vincent_C_Chen.jpg",
                licenseCode: "cc-by-sa",
                license: "CC BY-SA 3.0",
                source: "wikimedia_commons",
                attributionHTML: "\"Vincent C. Chen is a Taiwanese recreational diver and free diver who dedicate to underwater photography and the marine lives protection. He is also one of the contributors to EZDive magazine since 2008.\""
            )
        ]

        // Build TaxonItem using your new schema
        return TaxonItem(
            taxonId: 121261,
            scientificName: "Ablabys taenianotus",
            commonNameZh: "背帶帆鰭鮋",
            taxonomy: taxonomy,
            basicInfo: basicInfo,
            morphology: morphology,
            dietAndBehavior: dietAndBehavior,
            ecologyAndBehavior: ecologyAndBehavior,
            habitatAndDistribution: habitatAndDistribution,
            environmentAndDepth: environmentAndDepth,
            reproduction: reproduction,
            conservationAndHumanUses: conservationAndHumanUses,
            benefitsAndUses: BenefitsAndUses(
                fisheryAndFood: "非主要漁獲種，無顯著食用價值或商業漁業目標，偶因兼捕進入漁獲。",
                aquariumTrade: "偶見於專業海水觀賞魚市場或水族館展示，因外型特殊與擬態行為而具觀賞性，但飼養需求較高、對水質與環境較敏感。",
                ecologicalBenefits: "透過攝食底棲小型無脊椎動物與小魚，參與礁區與近岸食物網結構，並反映淺海底棲環境健康狀態，對生態系具有指標性與教育展示價值。"
            ),
            taiwanAndRegionalNotes: taiwanAndRegionalNotes,
            distribution: distribution,
            embeddingMeta: nil,
            growthAndLifeHistory: growthAndLifeHistory,
            photos: resolvedPhotos,
            wikiPhotos: wikiPhotos,
            distributionLayers: resolvedLayers
        )
    }
}
 

#Preview {
    NavigationStack {
        TaxonDetailView(taxon: .previewMock, sessionID: 1)
            .navigationTitle("FishBuddy")
    }
}
#endif

