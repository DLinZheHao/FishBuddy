//
//  ToastView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/11/19.
//

import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.8))
            )
            .shadow(radius: 8)
    }
}
