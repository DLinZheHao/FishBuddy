//
//  AppRoute.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/12.
//

import Foundation
import SwiftUI

enum AppRoute: Hashable, Codable {
    case taxon(id: Int)
}

enum DeepLinkRouter {
    static func parse(_ url: URL) -> AppRoute? {
        // fishbuddy://taxon/12345
        guard url.scheme?.lowercased() == "fishbuddy" else { return nil }

        // 注意：fishbuddy://taxon/12345 時，host = "taxon"，path = "/12345"
        let host = (url.host ?? "").lowercased()
        let pathParts = url.path.split(separator: "/").map(String.init)

        switch host {
        case "taxon":
            guard let first = pathParts.first, let id = Int(first) else { return nil }
            return .taxon(id: id)
        default:
            return nil
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var path = NavigationPath()

    func handleDeepLink(_ url: URL) {
        guard let route = DeepLinkRouter.parse(url) else { return }

        // 可選：避免一直疊同頁（最簡版先不管也行）
        // 這裡做「直接 push」
        path.append(route)
    }
}
