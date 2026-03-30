//
//  UserViewController.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct UserHomeView: View {
    /// viewModel
    @StateObject private var vm = UserHomeViewModel()
    
    var body: some View {
            NavigationStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        UserHomeTopBar()
                        UserHomeHeroSection()
                        UserHomeSearchBar()
                        FeatureSection()
                        
                        if !vm.taxonViewHistory.isEmpty {
                            FishSectionView(
                                title: "Recently Viewd" ,
                                actionTitle: "See All",
                                items: vm.taxonViewHistory.map(UserHomeSectionItem.taxonView))
                        }
                        
                        if !vm.response.isEmpty {
                            FishSectionView(
                                title: "Recent recognitions" ,
                                actionTitle: "See All",
                                items: vm.response.map(UserHomeSectionItem.recognition))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .navigationBarHidden(true)
            }
            .task {
                await vm.fetchTaxonViewHistory()
                await vm.fetchRecognitionSessions()
            }
        }
        
}

#Preview {
    UserHomeView()
}
