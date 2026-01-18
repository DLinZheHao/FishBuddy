//
//  DeepLinkRouterTests.swift
//  FishBuddyTests
//
//  Created by 林哲豪 on 2026/1/18.
//

import XCTest
@testable import FishBuddy

final class DeepLinkRouterTests: XCTestCase {

    func test_parse_taxon_deeplink_success() {
        let url = URL(string: "fishbuddy://taxon/121261")!
        let route = DeepLinkRouter.parse(url)

        // ↓ 這裡的 .taxon(id:) 依你的 Route 定義調整
        XCTAssertEqual(route, .taxon(id: 999))
    }

    func test_parse_invalid_scheme_returnsNil() {
        let url = URL(string: "http://taxon/121261")!
        let route = DeepLinkRouter.parse(url)

        XCTAssertNil(route)
    }

    func test_parse_nonNumeric_id_returnsNil() {
        let url = URL(string: "fishbuddy://taxon/abc")!
        let route = DeepLinkRouter.parse(url)

        XCTAssertNil(route)
    }

    func test_parse_unsupported_path_returnsNil() {
        let url = URL(string: "fishbuddy://unknown/123")!
        let route = DeepLinkRouter.parse(url)

        XCTAssertNil(route)
    }
}
