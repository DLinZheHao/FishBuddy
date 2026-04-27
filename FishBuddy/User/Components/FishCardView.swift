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
            if let sessionImage {
                let _ = print("session image: \(sessionImage)")
                Image(uiImage: sessionImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 160, maxHeight: 160)
                    .clipShape(
                        CustomRoundedRectangle(
                            topLeft: 16,
                            topRight: 16,
                            bottomLeft: 0,
                            bottomRight: 0
                        )
                    )
            } else {
                let _ = print("session image is nil")
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
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
            let image: UIImage?
            switch item {
            case .recognition(let session):
                image = try? await UserStore.shared.fetchSessionImage(sessionID: session.sessionID)
            case .taxonView(let history):
                image = try? await UserStore.shared.fetchTaxonViewImage(taxonID: history.taxonID)
            }
            await MainActor.run {
                sessionImage = image
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
