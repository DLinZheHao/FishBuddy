//
//  UserHomeSearchBar.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct UserHomeSearchBar: View {
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                Text("Search fish by name")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UserHomeSearchBar()
}
