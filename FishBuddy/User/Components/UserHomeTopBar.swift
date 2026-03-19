//
//  UserHomeTopBar.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/18.
//

import SwiftUI

struct UserHomeTopBar: View {
    // Set user preferences
    var onTapTrailing: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text("FishBuddy")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()

            Button(action: {
                onTapTrailing?()
            }) {
                Image(systemName: "gear")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    UserHomeTopBar()
}
