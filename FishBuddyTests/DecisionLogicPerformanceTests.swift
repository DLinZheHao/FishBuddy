//
//  DecisionLogicPerformanceTests.swift
//  FishBuddyTests
//
//  Created by 林哲豪 on 2026/2/11.
//

import XCTest
@testable import FishBuddy

final class DecisionLogicPerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    private func generateResults(total: Int, uniqueTaxon: Int) -> [EmbeddingStore.ScoredTaxon] {
        // 產生看起來像 iNat 的大 ID（不連號）
        let taxonIds: [Int] = (0..<uniqueTaxon).map { i in
            10_000 + (i * 7_919) % 9_000_000
        }
        
        return (0..<total).map { i in
            let taxonId = taxonIds[i % taxonIds.count]
            let score = Float((i * 37) % 101)
            return .init(taxonId: taxonId, score: score)
        }
    }
    
    func test_decideRanking_performance_U200() {
        let results = generateResults(total: 10_000, uniqueTaxon: 200)
        
        measure {
            _ = EmbeddingStore.decideTaxonRanking(from: results, acceptThreshold: 50)
        }
    }
    
    func test_decideRanking_performance_U2000() {
        let results = generateResults(total: 10_000, uniqueTaxon: 2000)
        
        measure {
            _ = EmbeddingStore.decideTaxonRanking(from: results, acceptThreshold: 50)
        }
    }
    
}
