//
//  CircleIconButton.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/12/31.
//

import SwiftUI
import UIKit
import MapKit

extension TaxonDetailView {
    
    struct SpeciesInfoHeader: View {
        let titleZh: String
        let scientificName: String
        let chips: [String]

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(titleZh)
                    .font(.system(size: 28, weight: .bold))

                Text(scientificName)
                    .font(.system(size: 18, weight: .semibold))
                    .italic()
                    .foregroundStyle(.secondary)

                Divider()
                
                if !chips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(chips, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.thinMaterial)   // ✅ 比較像你截圖那種膠囊感
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }
    
    struct StatPill: View {
        let model: StatPillModel

        var body: some View {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(model.color.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: model.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(model.color)
                }

                Text(model.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(model.value)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 92)
        }
    }

    struct QuickStatsRow: View {
        let items: [StatPillModel]

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(items) { item in
                        StatPill(model: item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    struct CircleIconButton: View {
        let systemName: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(systemName))
        }
    }

    /// UIKit share sheet wrapper
    struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
    
    struct SpeciesTabBar: View {
        @Binding var selected: SpeciesTab
        @Namespace private var indicatorNS

        private let indicatorWidth: CGFloat = 22
        private let indicatorHeight: CGFloat = 3

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(SpeciesTab.allCases) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selected = tab
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(tab.rawValue)
                                    .font(.system(size: 15, weight: tab == selected ? .semibold : .regular))
                                    .foregroundStyle(tab == selected ? .primary : .secondary)
                                    .frame(minWidth: 88)
                                
                                ZStack {
                                    if tab == selected {
                                        RoundedRectangle(cornerRadius: indicatorHeight / 2)
                                            .fill(Color.blue)
                                            .frame(width: 88 * 0.8, height: indicatorHeight)
                                            .matchedGeometryEffect(id: "tab_indicator", in: indicatorNS)
                                    } else {
                                        Color.clear
                                            .frame(width: indicatorWidth, height: indicatorHeight)
                                    }
                                }
                            }
                            .contentShape(Rectangle()) // 點擊範圍更穩
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
        }
    }
    
    struct SpeciesTabsPager: View {
        let taxonItem: TaxonItem
        @Binding var selected: SpeciesTab

        @State private var heights: [SpeciesTab: CGFloat] = [:]
        @State private var currentHeight: CGFloat = 400

        private let heightAnimation: Animation = .interactiveSpring(
            response: 0.35,
            dampingFraction: 0.85,
            blendDuration: 0.2
        )

        var body: some View {
            TabView(selection: $selected) {

                OverviewTab(taxonItem: taxonItem)
                    .tag(SpeciesTab.overview)
                    .background(HeightReader(tab: .overview))

                // Identification
                IdentificationTab(taxonItem: taxonItem)
                    .tag(SpeciesTab.identification)
                    .background(HeightReader(tab: .identification))

                // Range
                RangeTab(taxonItem: taxonItem)
                    .tag(SpeciesTab.range)
                    .background(HeightReader(tab: .range))
                
                // Habitat
                HabitatTab(taxonItem: taxonItem)
                    .tag(SpeciesTab.habitat)
                    .background(HeightReader(tab: .habitat))
                
                // Ecology
                EcologyTab(taxonItem: taxonItem)
                    .tag(SpeciesTab.ecology)
                    .background(HeightReader(tab: .ecology))

                // Life
                LifeTab(taxonItem: taxonItem)
                    .tag(SpeciesTab.life)
                    .background(HeightReader(tab: .life))
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // ✅ 不要系統底部 indicator
            .frame(height: currentHeight) // ✅ 關鍵：用量測結果撐開 TabView
//            .border(Color.red)   // Used for UI layout constraint testing
            .onPreferenceChange(TabHeightsKey.self) { dict in
                heights = dict
                if let h = heights[selected] {
                    // 防抖避免微小浮動
                    if abs(h - currentHeight) > 1 {
                        withAnimation(heightAnimation) {
                            currentHeight = h
                        }
                    }
                }
            }
            .onChange(of: selected) { _, newTab in
                if let h = heights[newTab] {
                    if abs(h - currentHeight) > 1 {
                        withAnimation(heightAnimation) {
                            currentHeight = h
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - TabView dynamic height helpers
    private struct TabHeightsKey: PreferenceKey {
        static var defaultValue: [SpeciesTab: CGFloat] = [:]
        static func reduce(value: inout [SpeciesTab: CGFloat], nextValue: () -> [SpeciesTab: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: max)
        }
    }

    private struct HeightReader: View {
        let tab: SpeciesTab
        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: TabHeightsKey.self, value: [tab: proxy.size.height])
            }
        }
    }
}

// MARK: Overview component
extension TaxonDetailView {
    struct OverviewTab: View {
        let taxonItem: TaxonItem

        var body: some View {
            VStack(spacing: 16) {

                if let summary = taxonItem.basicInfo?.summary,
                   !summary.isEmpty {
                    OverviewSummaryCard(text: summary)
                }

                if taxonItem.taxonomy != nil {
                    TaxonomyCard(taxonomy: taxonItem.taxonomy!)
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }
    
    struct OverviewSummaryCard: View {
        let text: String

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Summary")
                        .font(.headline)
                }

                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)   // ✅ 讓文字高度以內容為準
                    .layoutPriority(1)                              // ✅ 搶到需要的高度
                    .textSelection(.enabled)
            }
            .padding(16)
            .cardStyle()
        }
    }
    
    struct TaxonomyCard: View {
        let taxonomy: Taxonomy

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                Text("Taxonomy")
                    .font(.system(size: 16, weight: .semibold))

                VStack(spacing: 8) {
                    taxonomyRow(title: "Phylum", value: taxonomy.phylum)
                    taxonomyRow(title: "Class", value: taxonomy.classType)
                    taxonomyRow(title: "Order", value: taxonomy.order)
                    taxonomyRow(title: "Family", value: taxonomy.family)
                    taxonomyRow(title: "Genus", value: taxonomy.genus)
                }
            }
            .padding(16)
            .cardStyle()
        }

        @ViewBuilder
        private func taxonomyRow(title: String, value: String?) -> some View {
            if let value, !value.isEmpty {
                HStack {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }
}

// MARK: IdentificationTab Component
extension TaxonDetailView {

    // 1️⃣ IdentificationTab（tab 本體）
    struct IdentificationTab: View {
        let taxonItem: TaxonItem

        var body: some View {
            VStack(spacing: 16) {
                if let morphology = taxonItem.morphology {
                    IdentificationCard(morphology: morphology)
                } else {
                    IdentificationEmptyCard()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }

    // 2️⃣ IdentificationCard（主要內容卡）
    struct IdentificationCard: View {
        let morphology: Morphology

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                // Header
                HStack(spacing: 8) {
                    Image(systemName: "eye.circle.fill")
                        .foregroundStyle(.blue)

                    Text("Identification")
                        .font(.system(size: 16, weight: .semibold))
                }

                // Content
                VStack(alignment: .leading, spacing: 10) {
                    bulletRow(
                        title: "Body shape",
                        text: morphology.bodyShape
                    )

                    bulletRow(
                        title: "Color & pattern",
                        text: morphology.colorationAndPattern
                    )

                    bulletRow(
                        title: "Fins & features",
                        text: morphology.finsAndSpecialFeatures
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }

        // 3️⃣ Bullet Row（dot + text）
        @ViewBuilder
        private func bulletRow(title: String, text: String?) -> some View {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .textSelection(.enabled)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    // 4️⃣ Empty State（資料缺失時）
    struct IdentificationEmptyCard: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(.secondary)

                    Text("Identification")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text("No morphology data available.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }
    }
}

// MARK: HabitatTab Component
extension TaxonDetailView {

    struct HabitatTab: View {
        let taxonItem: TaxonItem

        var body: some View {
            VStack(spacing: 16) {
                HabitatCard(
                    localHabitat: taxonItem.habitatAndDistribution?.localHabitatType,
                    globalDistribution: taxonItem.habitatAndDistribution?.globalDistribution,
                    environment: taxonItem.environmentAndDepth?.environment,
                    depth: taxonItem.environmentAndDepth?.depthRangeM
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }

    struct HabitatCard: View {
        let localHabitat: String?
        let globalDistribution: String?
        let environment: String?
        let depth: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 8) {
                    Image(systemName: "leaf.circle.fill")
                        .foregroundStyle(.green)

                    Text("Habitat")
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow(title: "Local habitat", text: localHabitat)
                    bulletRow(title: "Environment", text: environment)
                    bulletRow(title: "Depth", text: depth.map(normalizeDepth))

                    // 放最後：通常比較長
                    bulletRow(title: "Global distribution", text: globalDistribution)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }

        @ViewBuilder
        private func bulletRow(title: String, text: String?) -> some View {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .textSelection(.enabled)
                    }
                }
            } else {
                EmptyView()
            }
        }

        private func normalizeDepth(_ raw: String) -> String {
            raw
                .replacingOccurrences(of: "公尺", with: " m")
                .replacingOccurrences(of: "米", with: " m")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: EcologyTab Component
extension TaxonDetailView {

    struct EcologyTab: View {
        let taxonItem: TaxonItem

        var body: some View {
            VStack(spacing: 16) {

                EcologyOverviewCard(
                    generalEcology: taxonItem.ecologyAndBehavior?.generalEcology,
                    socialStructure: taxonItem.ecologyAndBehavior?.socialStructure,
                    dailyRhythm: taxonItem.ecologyAndBehavior?.dailyRhythm
                )

                DietCard(
                    diet: taxonItem.dietAndBehavior?.diet,
                    foraging: taxonItem.dietAndBehavior?.foragingBehavior
                )

                // 可選：區域生態角色（你想放 Ecology 很合理）
                if let role = taxonItem.taiwanAndRegionalNotes?.regionalEcologicalRole,
                   !role.isEmpty {
                    RegionalRoleCard(text: role)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }

    struct EcologyOverviewCard: View {
        let generalEcology: String?
        let socialStructure: String?
        let dailyRhythm: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 8) {
                    Image(systemName: "leaf.circle.fill")   // ✅ 穩定存在
                        .foregroundStyle(.teal)

                    Text("Ecology")
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow(title: "Ecology", text: generalEcology)
                    bulletRow(title: "Social structure", text: socialStructure)
                    bulletRow(title: "Daily rhythm", text: dailyRhythm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }

        @ViewBuilder
        private func bulletRow(title: String, text: String?) -> some View {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.teal)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .textSelection(.enabled)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    struct DietCard: View {
        let diet: String?
        let foraging: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle")  // ✅ 比 fill 更穩
                        .foregroundStyle(.orange)

                    Text("Diet")
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow(title: "Diet", text: diet)
                    bulletRow(title: "Foraging behavior", text: foraging)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }

        @ViewBuilder
        private func bulletRow(title: String, text: String?) -> some View {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .textSelection(.enabled)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    struct RegionalRoleCard: View {
        let text: String

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse.circle.fill")
                        .foregroundStyle(.indigo)

                    Text("Regional role")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .textSelection(.enabled)
            }
            .padding(16)
            .cardStyle()
        }
    }
}

// MARK: LifeTab Component
extension TaxonDetailView {

    struct LifeTab: View {
        let taxonItem: TaxonItem

        var body: some View {
            VStack(spacing: 16) {

                GrowthCard(
                    maxLength: taxonItem.growthAndLifeHistory?.maximumLengthCm,
                    growthNotes: taxonItem.growthAndLifeHistory?.growthNotes,
                    lifeHistory: taxonItem.growthAndLifeHistory?.lifeHistoryNotes
                )

                ReproductionCard(
                    mode: taxonItem.reproduction?.reproductiveMode,
                    spawning: taxonItem.reproduction?.spawningBehavior,
                    parentalCare: taxonItem.reproduction?.parentalCare
                )

                ConservationAndUsesCard(
                    status: taxonItem.conservationAndHumanUses?.conservationStatus,
                    threats: taxonItem.conservationAndHumanUses?.threats,
                    protection: taxonItem.conservationAndHumanUses?.managementOrProtection,
                    fishery: taxonItem.benefitsAndUses?.fisheryAndFood,
                    aquarium: taxonItem.benefitsAndUses?.aquariumTrade,
                    ecoBenefits: taxonItem.benefitsAndUses?.ecologicalBenefits
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }

    // MARK: - Growth
    struct GrowthCard: View {
        let maxLength: String?
        let growthNotes: String?
        let lifeHistory: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 8) {
                    Image(systemName: "ruler.fill")
                        .foregroundStyle(.purple)

                    Text("Growth & life history")
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow(title: "Max size", text: maxLength)
                    bulletRow(title: "Growth", text: growthNotes)
                    bulletRow(title: "Life history", text: lifeHistory)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }

        @ViewBuilder
        private func bulletRow(title: String, text: String?) -> some View {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .textSelection(.enabled)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Reproduction
    struct ReproductionCard: View {
        let mode: String?
        let spawning: String?
        let parentalCare: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(.pink)

                    Text("Reproduction")
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow(title: "Mode", text: mode)
                    bulletRow(title: "Spawning", text: spawning)
                    bulletRow(title: "Parental care", text: parentalCare)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }

        @ViewBuilder
        private func bulletRow(title: String, text: String?) -> some View {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .textSelection(.enabled)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Conservation & Uses
    struct ConservationAndUsesCard: View {
        let status: String?
        let threats: String?
        let protection: String?

        let fishery: String?
        let aquarium: String?
        let ecoBenefits: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(.indigo)

                    Text("Conservation & uses")
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow(title: "Status", text: status)
                    bulletRow(title: "Threats", text: threats)
                    bulletRow(title: "Protection", text: protection)

                    Divider().padding(.vertical, 2)

                    bulletRow(title: "Fishery/food", text: fishery)
                    bulletRow(title: "Aquarium trade", text: aquarium)
                    bulletRow(title: "Ecological benefits", text: ecoBenefits)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }

        @ViewBuilder
        private func bulletRow(title: String, text: String?) -> some View {
            if let text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.indigo)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .textSelection(.enabled)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: RangeTab Component
extension TaxonDetailView {

    struct RangeTab: View {
        let taxonItem: TaxonItem

        var body: some View {
            VStack(spacing: 16) {
                MapPreviewCard(taxonId: taxonItem.taxonId)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }
    
    struct MapPreviewCard: View {
        let taxonId: Int

        // iOS 17+ Map initializer: bind camera position instead of deprecated region API
        @State private var cameraPosition: MapCameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.7, longitude: 121.0),
                span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 60)
            )
        )

        var body: some View {
            NavigationLink {
                TaxonDistributionView(taxonId: taxonId)
                    .navigationTitle("地圖")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                VStack(alignment: .leading, spacing: 12) {

                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .foregroundStyle(.blue)
                            Text("Distribution map")
                                .font(.system(size: 16, weight: .semibold))
                        }

                        Spacer()

                        Text("Open")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Map(position: $cameraPosition) {
                        // No additional content/annotations in preview
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .allowsHitTesting(false) // ✅ 不可互動，避免誤導
                }
                .padding(16)
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }
}

extension TaxonDetailView {
    
    enum SpeciesTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case identification = "ID"
        case range = "Range"
        case habitat = "Habitat"
        case ecology = "Ecology"
        case life = "Life"
        
        var id: String { rawValue }
    }
    
}
