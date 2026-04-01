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

struct CollectionView: View {
    @StateObject private var vm = CollectionViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("My Fish Collection")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.label))

                    CollectionSearchControls(
                        searchText: $vm.searchText,
                        selectedFilter: $vm.selectedFilter
                    )

                    CollectionSegmentedControl(selection: $vm.selectedSection)

                    if let errorMessage = vm.errorMessage {
                        CollectionStateView(
                            systemImage: "exclamationmark.triangle",
                            title: "Unable to load collection",
                            message: errorMessage
                        )
                    } else if vm.filteredCards.isEmpty {
                        CollectionStateView(
                            systemImage: "water.waves",
                            title: "No fish found",
                            message: vm.emptyStateMessage
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(vm.filteredCards) { card in
                                CollectionFishCard(
                                    card: card,
                                    toggleFavorite: {
                                        await vm.toggleFavorite(for: card.taxonID)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .task {
            await vm.load()
        }
    }
}

private struct CollectionSearchControls: View {
    @Binding var searchText: String
    @Binding var selectedFilter: CollectionEnvironmentFilter

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Search collection...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
            )

            Menu {
                ForEach(CollectionEnvironmentFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        if selectedFilter == filter {
                            Label(filter.title, systemImage: "checkmark")
                        } else {
                            Text(filter.title)
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 64, height: 64)

                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.03, green: 0.49, blue: 0.54))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CollectionSegmentedControl: View {
    @Binding var selection: CollectionSection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CollectionSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = section
                    }
                } label: {
                    Text(section.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == section ? Color(.label) : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            Capsule()
                                .fill(selection == section ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct CollectionFishCard: View {
    let card: CollectionCard
    let toggleFavorite: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(card.imageBackground)
                    .frame(height: 188)

                fishImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)

                favoriteButton
                    .padding(14)

                habitatBadge
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)

                Text(card.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 20, y: 10)
        )
    }

    @ViewBuilder
    private var fishImage: some View {
        if let imageURL = card.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure(_):
                    imagePlaceholder
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        Image(systemName: "fish")
            .font(.system(size: 44, weight: .regular))
            .foregroundStyle(.white.opacity(0.85))
    }

    private var habitatBadge: some View {
        Text(card.habitatBadgeTitle)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(card.habitatBadgeColor)
            )
    }

    private var favoriteButton: some View {
        Button {
            Task {
                await toggleFavorite()
            }
        } label: {
            Image(systemName: card.isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(card.isFavorite ? Color.white : Color.white.opacity(0.95))
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(card.isFavorite ? 0.32 : 0.18))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct CollectionStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview("Collection") {
    CollectionView()
}
