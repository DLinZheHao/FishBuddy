//
//  FishCardView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct FishCardView: View {
    let item: UserHomeSectionItem
    @State private var sessionImage: UIImage?
    @State private var isLoadingImage = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private var title: String {
        let date = Date(timeIntervalSince1970: TimeInterval(item.createdAt))
        return Self.dateFormatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let sessionImage {
                    let _ = print("session image: \(sessionImage)")
//                    KFImage(imageURL)
                    Image(uiImage: sessionImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160)
                        .frame(height: 120)
                        .clipShape(
                            CustomRoundedRectangle(
                                topLeft: 16,
                                topRight: 16,
                                bottomLeft: 0,
                                bottomRight: 0
                            )
                        )
                } else if isLoadingImage {
                    VStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.regular)
                        Spacer()
                    }
                    .frame(width: 160)
                    .frame(height: 120)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("No Image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 160)
                    .frame(height: 120)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
        }
        .frame(width: 160)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .task(id: item.id) {
            await MainActor.run {
                isLoadingImage = true
                sessionImage = nil
            }

            let image: UIImage?
            switch item {
            case .recognition(let session):
                image = try? await UserStore.shared.fetchSessionImage(sessionID: session.sessionID)
            case .taxonView(let history):
                image = try? await UserStore.shared.fetchTaxonViewImage(taxonID: history.taxonID)
            }

            await MainActor.run {
                sessionImage = image
                isLoadingImage = false
            }
        }
    }
}

#Preview {
    FishCardView(
        item: .recognition(
            RecognitionSessionDetail(
                sessionID: 1,
                createdAt: 0,
                imagePath: nil,
                source: "preview",
                results: []
            )
        )
    )
}
