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
    let items: [UserHomeSectionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UserSectionHeaderView(title: title,
                                  actionTitle: actionTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items) { item in
                        FishCardView(
                            item: item
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

#Preview {
    FishSectionView(
        title: "Test Section" ,
        actionTitle: "See All",
        items: [])
}
