//
//  AppCoordinator.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/12.
//

import UIKit
import SwiftUI

final class AppCoordinator {
    let nav: UINavigationController

    init(nav: UINavigationController) {
        self.nav = nav
    }

    func handleDeepLink(_ url: URL) {
        guard let route = DeepLinkRouter.parse(url) else { return }
        navigate(to: route)
    }

    func navigate(to route: AppRoute) {
        print("進入導航")
           switch route {
           case .taxon(let id):
               Task { [weak self] in
                   guard let self else { return }
                   guard let fishDB = await EmbeddingStore.shared.fishDB else { return }

                   let item = try fishDB.loadTaxonItems(taxonIds: [id])

                   await MainActor.run {
                       guard let taxon = item.first else { return }
                       let view = TaxonDetailView(taxon: taxon)
                       let vc = UIHostingController(rootView: view)
                       self.nav.pushViewController(vc, animated: true)
                   }
               }
           }
       }
}
