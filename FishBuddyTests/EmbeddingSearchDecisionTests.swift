//
//  EmbeddingSearchDecisionTests.swift
//  FishBuddyTests
//
//  Created by 林哲豪 on 2026/1/20.
//

import XCTest
@testable import FishBuddy

final class EmbeddingSearchDecisionTests: XCTestCase {

    func test_decideRanking_emptyResults_returnsEmpty() throws {
        let ranked = EmbeddingStore.decideTaxonRanking(from: [], acceptThreshold: 50)
        XCTAssertTrue(ranked.isEmpty)
    }

    func test_decideRanking_keepsMaxScorePerTaxon() throws {
        let results: [EmbeddingStore.ScoredTaxon] = [
            .init(taxonId: 1, score: 60),
            .init(taxonId: 1, score: 88), // same taxon, higher score should win
            .init(taxonId: 2, score: 70),
            .init(taxonId: 2, score: 65)
        ]

        let ranked = EmbeddingStore.decideTaxonRanking(from: results, acceptThreshold: 0)

        // Expect taxon 1 uses 88, taxon 2 uses 70
        XCTAssertEqual(ranked.count, 2)
        XCTAssertEqual(ranked.first?.taxonId, 1)
        let first = try XCTUnwrap(ranked.first)
        XCTAssertEqual(Double(first.score), 88.0, accuracy: 0.0001)

        XCTAssertEqual(ranked.last?.taxonId, 2)
        let last = try XCTUnwrap(ranked.last)
        XCTAssertEqual(Double(last.score), 70.0, accuracy: 0.0001)
    }

    func test_decideRanking_appliesThreshold_filtersLowScores() throws {
        let results: [EmbeddingStore.ScoredTaxon] = [
            .init(taxonId: 1, score: 49),
            .init(taxonId: 2, score: 50),
            .init(taxonId: 3, score: 99)
        ]

        let ranked = EmbeddingStore.decideTaxonRanking(from: results, acceptThreshold: 50)

        // taxon 1 should be filtered out, 2 and 3 remain
        XCTAssertEqual(ranked.map(\.taxonId), [3, 2])
        XCTAssertEqual(ranked.map(\.score), [Float(99), Float(50)])
    }

    func test_decideRanking_thresholdFiltersAll_returnsEmpty() throws {
        let results: [EmbeddingStore.ScoredTaxon] = [
            .init(taxonId: 1, score: 10),
            .init(taxonId: 2, score: 20)
        ]

        let ranked = EmbeddingStore.decideTaxonRanking(from: results, acceptThreshold: 90)
        XCTAssertTrue(ranked.isEmpty)
    }

    func test_decideRanking_thresholdZero_disablesFiltering() throws {
        let results: [EmbeddingStore.ScoredTaxon] = [
            .init(taxonId: 1, score: 10),
            .init(taxonId: 2, score: 20)
        ]

        let ranked = EmbeddingStore.decideTaxonRanking(from: results, acceptThreshold: 0)

        // No filtering; still sorted desc
        XCTAssertEqual(ranked.map(\.taxonId), [2, 1])
        XCTAssertEqual(ranked.map(\.score), [Float(20), Float(10)])
    }

    func test_decideRanking_sortsDescendingByScore() throws {
        let results: [EmbeddingStore.ScoredTaxon] = [
            .init(taxonId: 1, score: 70),
            .init(taxonId: 2, score: 90),
            .init(taxonId: 3, score: 80)
        ]

        let ranked = EmbeddingStore.decideTaxonRanking(from: results, acceptThreshold: 0)
        XCTAssertEqual(ranked.map(\.taxonId), [2, 3, 1])
    }
}
