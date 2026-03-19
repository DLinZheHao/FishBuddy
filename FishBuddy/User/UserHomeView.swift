//
//  UserViewController.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct UserHomeView: View {
    var body: some View {
            NavigationStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        UserHomeTopBar()
                        UserHomeHeroSection()
                        UserHomeSearchBar()
                        FeatureSection()
                        FishSectionView(
                            title: "Test Section" ,
                            actionTitle: "See All",
                            items: [
                            FishCardItem(title: "Clownfish", subtitle: "Amphiprioninae", imageName: "fish1"),
                            FishCardItem(title: "Blue Tang", subtitle: "Paracanthurus hepatus", imageName: "fish2"),
                            FishCardItem(title: "Lionfish", subtitle: "Pterois", imageName: "fish3"),
                            FishCardItem(title: "Goldfish", subtitle: "Carassius auratus", imageName: "fish4")
                        ])
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
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .navigationBarHidden(true)
            }
        }
}

#Preview {
    UserHomeView()
}


