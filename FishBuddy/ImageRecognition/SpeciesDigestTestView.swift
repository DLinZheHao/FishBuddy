//
//  SpeciesDigestTestView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/11.
//

import SwiftUI

@available(iOS 26.0, *)
struct SpeciesDigestDebugView: View {

    @State var generator: SpeciesDigestGenerator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("🧪 Species Digest Test")
                .font(.title2)
                .bold()

            Divider()

            content

            Spacer()
        }
        .padding()
        .task {
            generator.prewarmModel()
            await generator.generateAll()
        }
    }

    @ViewBuilder
    private var content: some View {
        // ❶ Error
        if let error = generator.error {
            VStack(alignment: .leading, spacing: 8) {
                Text("❌ Error")
                    .font(.headline)
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            }
        }
        // ❷ Success（已有任何 partial output）
        else if let partial = generator.speciesDigest {
            DigestResultView(partial: partial)
        }
        // ❸ Loading
        else {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView()
                Text("Generating species digest…")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@available(iOS 26.0, *)
struct DigestResultView: View {

    let partial: SpeciesDigest.PartiallyGenerated

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                field("Title", partial.titleZh)
                field("Key Traits", partial.keyTraits?.joined(separator: " / "))
                field("Habitat", partial.habitatSummary)
                field("Confusion Tip", partial.confusionTip)
                field("Safety Note", partial.safetyNote)
                field("Coverage", partial.coverage)

            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func field(_ name: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value ?? "—")
                .font(.body)
                .textSelection(.enabled)
        }
    }
}
