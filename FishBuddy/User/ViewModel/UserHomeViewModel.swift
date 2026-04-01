//
//  UserHomeViewModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class UserHomeViewModel: ObservableObject {
    @Published var response: [RecognitionSessionDetail] = []
    @Published var taxonViewHistory: [TaxonViewHistoryDetail] = []
    @Published var errorMessage: String?

    func fetchRecognitionSessions(limit: Int = 50) async {
        do {
            response = try await UserStore.shared.fetchRecognitionSessions(limit: limit)
            errorMessage = nil
            print("成功： 成功取得識別紀錄 \(response.count)")
        } catch {
            response = []
            errorMessage = error.localizedDescription
            print("發生錯誤： \(error.localizedDescription)")
        }
    }

    func fetchTaxonViewHistory(limit: Int = 50) async {
        do {
            taxonViewHistory = try await UserStore.shared.fetchTaxonViewHistory(limit: limit)
            errorMessage = nil
            print("成功： 成功取得瀏覽紀錄 \(taxonViewHistory.count)")
        } catch {
            taxonViewHistory = []
            errorMessage = error.localizedDescription
            print("發生錯誤： \(error.localizedDescription)")
        }
    }
}

@MainActor
final class CollectionViewModel: ObservableObject {
    @Published var selectedSection: CollectionSection = .favorites
    @Published var selectedFilter: CollectionEnvironmentFilter = .all
    @Published var searchText = ""
    @Published var errorMessage: String?

    @Published private(set) var favoriteCards: [CollectionCard] = []
    @Published private(set) var recognitionCards: [CollectionCard] = []
    @Published private(set) var historyCards: [CollectionCard] = []

    var filteredCards: [CollectionCard] {
        activeCards.filter(matchesSearch).filter(matchesFilter)
    }

    var emptyStateMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Try another keyword or switch a different segment."
        }

        switch selectedSection {
        case .favorites:
            return "Favorite fish will show up here after you tap the heart button."
        case .recognitions:
            return "Recognition results will appear here after you identify a fish."
        case .history:
            return "Viewed species will be listed here after you open a fish detail page."
        }
    }

    private var activeCards: [CollectionCard] {
        switch selectedSection {
        case .favorites:
            return favoriteCards
        case .recognitions:
            return recognitionCards
        case .history:
            return historyCards
        }
    }

    func load() async {
        do {
            let favoriteTaxonIDs = try await UserStore.shared.fetchFavoriteTaxonIDs(limit: 200)
            let recognitionSessions = try await UserStore.shared.fetchRecognitionSessions(limit: 80)
            let historyEntries = try await UserStore.shared.fetchTaxonViewHistory(limit: 80)

            guard let fishDB = await EmbeddingStore.shared.fishDB else {
                errorMessage = "Fish database is not ready yet."
                return
            }

            let recognitionTaxonIDs = recognitionSessions.compactMap { $0.results.first?.taxonID }
            let historyTaxonIDs = historyEntries.map(\.taxonID)
            let taxonIDs = orderedUniqueIDs(favoriteTaxonIDs + recognitionTaxonIDs + historyTaxonIDs)
            let taxonItems = try fishDB.loadTaxonItems(taxonIds: taxonIDs)
            let taxonByID = Dictionary(uniqueKeysWithValues: taxonItems.map { ($0.taxonId, $0) })
            let favoriteSet = Set(favoriteTaxonIDs)

            favoriteCards = favoriteTaxonIDs.compactMap { taxonID in
                guard let taxon = taxonByID[taxonID] else { return nil }
                return CollectionCard(
                    sourceID: "favorite-\(taxonID)",
                    taxon: taxon,
                    isFavorite: true,
                    sessionID: nil
                )
            }

            recognitionCards = recognitionSessions.compactMap { session in
                guard let taxonID = session.results.first?.taxonID,
                      let taxon = taxonByID[taxonID] else { return nil }

                return CollectionCard(
                    sourceID: "recognition-\(session.sessionID)",
                    taxon: taxon,
                    isFavorite: favoriteSet.contains(taxonID),
                    sessionID: session.sessionID
                )
            }

            historyCards = historyEntries.compactMap { entry in
                guard let taxon = taxonByID[entry.taxonID] else { return nil }

                return CollectionCard(
                    sourceID: "history-\(entry.id)",
                    taxon: taxon,
                    isFavorite: favoriteSet.contains(entry.taxonID),
                    sessionID: entry.sessionID
                )
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            favoriteCards = []
            recognitionCards = []
            historyCards = []
        }
    }

    func toggleFavorite(for taxonID: Int) async {
        do {
            let isFavorite = try await UserStore.shared.toggleFavorite(taxonID: taxonID)
            applyFavoriteState(isFavorite, to: taxonID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyFavoriteState(_ isFavorite: Bool, to taxonID: Int) {
        favoriteCards = favoriteCards.filter { $0.taxonID != taxonID }

        recognitionCards = recognitionCards.map { card in
            guard card.taxonID == taxonID else { return card }
            return card.withFavoriteState(isFavorite)
        }

        historyCards = historyCards.map { card in
            guard card.taxonID == taxonID else { return card }
            return card.withFavoriteState(isFavorite)
        }

        guard isFavorite else { return }

        if let recognitionCard = recognitionCards.first(where: { $0.taxonID == taxonID }) {
            favoriteCards.insert(recognitionCard.withFavoriteState(true), at: 0)
        } else if let historyCard = historyCards.first(where: { $0.taxonID == taxonID }) {
            favoriteCards.insert(historyCard.withFavoriteState(true), at: 0)
        }
    }

    private func matchesSearch(_ card: CollectionCard) -> Bool {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return true }

        return card.title.localizedCaseInsensitiveContains(keyword)
        || card.subtitle.localizedCaseInsensitiveContains(keyword)
    }

    private func matchesFilter(_ card: CollectionCard) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .marine:
            return card.habitatCategory == .marine
        case .freshwater:
            return card.habitatCategory == .freshwater
        }
    }

    private func orderedUniqueIDs(_ ids: [Int]) -> [Int] {
        var seen = Set<Int>()
        return ids.filter { seen.insert($0).inserted }
    }
}

enum CollectionSection: String, CaseIterable, Identifiable {
    case favorites
    case recognitions
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites:
            return "Favorites"
        case .recognitions:
            return "Recognitions"
        case .history:
            return "History"
        }
    }
}

enum CollectionEnvironmentFilter: String, CaseIterable, Identifiable {
    case all
    case marine
    case freshwater

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .marine:
            return "Marine"
        case .freshwater:
            return "Freshwater"
        }
    }
}

enum CollectionHabitatCategory: String {
    case marine
    case freshwater
    case unknown

    var badgeTitle: String {
        switch self {
        case .marine:
            return "Marine"
        case .freshwater:
            return "Freshwater"
        case .unknown:
            return "Unknown"
        }
    }

    var badgeColor: Color {
        switch self {
        case .marine:
            return Color(red: 0.05, green: 0.74, blue: 0.68)
        case .freshwater:
            return Color(red: 0.16, green: 0.64, blue: 0.96)
        case .unknown:
            return Color(red: 0.48, green: 0.52, blue: 0.60)
        }
    }

    var imageBackground: LinearGradient {
        switch self {
        case .marine:
            return LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.13),
                    Color(red: 0.00, green: 0.00, blue: 0.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .freshwater:
            return LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.11, blue: 0.10),
                    Color(red: 0.05, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .unknown:
            return LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.20, blue: 0.25),
                    Color(red: 0.08, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func from(_ taxon: TaxonItem) -> CollectionHabitatCategory {
        let keywords = [
            taxon.environmentAndDepth?.environment,
            taxon.habitatAndDistribution?.localHabitatType,
            taxon.habitatAndDistribution?.globalDistribution
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if keywords.contains("fresh")
            || keywords.contains("river")
            || keywords.contains("lake")
            || keywords.contains("stream")
            || keywords.contains("pond") {
            return .freshwater
        }

        if keywords.contains("marine")
            || keywords.contains("reef")
            || keywords.contains("sea")
            || keywords.contains("ocean")
            || keywords.contains("coast") {
            return .marine
        }

        return .unknown
    }
}

struct CollectionCard: Identifiable {
    let id: String
    let taxonID: Int
    let title: String
    let subtitle: String
    let imageURL: String?
    let habitatCategory: CollectionHabitatCategory
    let isFavorite: Bool
    let sessionID: Int64?
    let taxon: TaxonItem

    init(sourceID: String, taxon: TaxonItem, isFavorite: Bool, sessionID: Int64?) {
        let trimmedCommonName = taxon.commonNameZh?.trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = sourceID
        self.taxonID = taxon.taxonId
        self.title = (trimmedCommonName?.isEmpty == false) ? trimmedCommonName! : taxon.scientificName
        self.subtitle = taxon.scientificName
        self.imageURL = taxon.photos.first?.url ?? taxon.wikiPhotos.first?.url
        self.habitatCategory = CollectionHabitatCategory.from(taxon)
        self.isFavorite = isFavorite
        self.sessionID = sessionID
        self.taxon = taxon
    }

    var habitatBadgeTitle: String {
        habitatCategory.badgeTitle
    }

    var habitatBadgeColor: Color {
        habitatCategory.badgeColor
    }

    var imageBackground: LinearGradient {
        habitatCategory.imageBackground
    }

    func withFavoriteState(_ isFavorite: Bool) -> CollectionCard {
        CollectionCard(
            sourceID: id,
            taxon: taxon,
            isFavorite: isFavorite,
            sessionID: sessionID
        )
    }
}
