//
//  UserPromptView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/17.
//

import SwiftUI

struct UserPromptView: View {
    /// 提示資料
    let prompt: UserPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !prompt.morphology.isEmpty {
                categorySection(title: "形態", tags: prompt.morphology)
            }
            if !prompt.pattern.isEmpty {
                categorySection(title: "圖案", tags: prompt.pattern)
            }
            if !prompt.traits.isEmpty {
                categorySection(title: "特徵", tags: prompt.traits)
            }
            if !prompt.habitat.isEmpty {
                categorySection(title: "棲息地", tags: prompt.habitat)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Components
    @ViewBuilder
    private func categorySection(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            WrapLayout(spacing: 8, runSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(Color.blue.opacity(0.9))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
}

// MARK: - Preview Example
struct UserPromptView_Previews: PreviewProvider {
    static var previews: some View {
        UserPromptView(
            prompt: UserPrompt(
                morphology: ["Fusiform", "Compressed", "Elongated"],
                pattern: ["Striped", "Spotted", "Solid"],
                traits: ["Large Mouth", "Small Mouth", "Sharp Teeth"],
                habitat: ["Freshwater", "Saltwater", "Brackish"]
            )
        )
        .previewLayout(.sizeThatFits)
        .background(Color(white: 0.96))
    }
}
