//
//  SideButton.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/11/16.
//

import SwiftUI

struct SideButton: View {
    let icon: String
    let title: String
    let isActive: Bool?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isActive ?? false ? .green : .white)
                .padding(8)
                .background(.ultraThinMaterial,
                            in: Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SideButton(
        icon: "star.fill",
        title: "Favorite",
        isActive: true,
        action: {}
    )
}
