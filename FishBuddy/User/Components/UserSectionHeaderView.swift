//
//  UserSectionHeaderView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct UserSectionHeaderView: View {
    let title: String
        let actionTitle: String?
        var onTapAction: (() -> Void)? = nil

        var body: some View {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if let actionTitle {
                    Button(action: {
                        onTapAction?()
                    }) {
                        Text(actionTitle)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
}

#Preview {
    UserSectionHeaderView(title: "Recently Viewed", actionTitle: "See all")
}

