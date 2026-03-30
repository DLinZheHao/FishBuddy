//
//  UserStoreModels.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/25.
//

import Foundation
import UIKit

struct RecognitionSessionDetail: Identifiable {
    var id: Int64 { sessionID }
    let sessionID: Int64
    let createdAt: Int64
    let imagePath: String?
    let source: String
    
    let results: [RecognitionCandidate]
}

struct RecognitionCandidate {
    let taxonID: Int
    let score: Double
    let rank: Int64
}

struct TaxonViewHistoryDetail: Identifiable {
    let id: Int64
    let createdAt: Int64
    let taxonID: Int
    let sessionID: Int64?
    let entry: String
}

enum UserHomeSectionItem: Identifiable {
    case recognition(RecognitionSessionDetail)
    case taxonView(TaxonViewHistoryDetail)

    var id: String {
        switch self {
        case .recognition(let session):
            return "recognition-\(session.id)"
        case .taxonView(let history):
            return "taxon-view-\(history.id)"
        }
    }

    var createdAt: Int64 {
        switch self {
        case .recognition(let session):
            return session.createdAt
        case .taxonView(let history):
            return history.createdAt
        }
    }

    var subtitle: String {
        switch self {
        case .recognition(let session):
            if let topResult = session.results.first {
                return "Taxon ID: \(topResult.taxonID)"
            }
            return session.source
        case .taxonView(let history):
            return "Taxon ID: \(history.taxonID)"
        }
    }
}
