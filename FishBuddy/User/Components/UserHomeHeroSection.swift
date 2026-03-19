//
//  UserHomeHeroSection.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct UserHomeHeroSection: View {
    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Discover the ocean’s life")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Explore species, revisit sightings, and recognize fish around you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
}

#Preview {
    UserHomeHeroSection()
}
