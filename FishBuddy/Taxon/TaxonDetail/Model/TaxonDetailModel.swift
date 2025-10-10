//
//  TaxonDetailModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/10.
//

import Foundation
import SwiftUI

// MARK: - Minimal Models (self-contained for drop-in)
struct FishDistributionLayer: Codable, Hashable, Identifiable {
    var id: String { key }
    let key: String
    let type: String
    let url: String
    let minzoom: Int
    let maxzoom: Int
}

struct FishDistribution: Codable, Hashable {
    let type: String
    let layers: [FishDistributionLayer]
    let kml_url: String?
    let placesSummary: String? // optional short text like "North Atlantic"
}

struct Taxon: Identifiable, Hashable {
    let id: Int
    let commonName: String
    let scientificName: String
    let conservationBadge: String? // e.g. "Least Concern"
    let heroImageURL: URL?
    let overview: String
    let ecology: String?
    let distribution: FishDistribution?
}
