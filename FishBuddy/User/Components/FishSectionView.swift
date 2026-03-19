//
//  RecentlyViewedSection.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/19.
//

import SwiftUI

struct FishSectionView: View {
    let title: String
    let actionTitle: String
    let items: [FishCardItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UserSectionHeaderView(title: title,
                                  actionTitle: actionTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items) { item in
                        FishCardView(
                            title: item.title,
                            subtitle: item.subtitle,
                            imageName: item.imageName
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}
struct FishCardItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageName: String
}
#Preview {
    FishSectionView(
        title: "Test Section" ,
        actionTitle: "See All",
        items: [
        FishCardItem(title: "Clownfish", subtitle: "Amphiprioninae", imageName: "fish1"),
        FishCardItem(title: "Blue Tang", subtitle: "Paracanthurus hepatus", imageName: "fish2"),
        FishCardItem(title: "Lionfish", subtitle: "Pterois", imageName: "fish3"),
        FishCardItem(title: "Goldfish", subtitle: "Carassius auratus", imageName: "fish4")
    ])
}
