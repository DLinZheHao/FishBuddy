//
//  SpeciesDigestTestView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/11.
//

import SwiftUI

@available(iOS 26.0, *)
struct SpeciesDigestDebugView: View {

    @State var vm: SpeciesDigestViewModel

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
            vm.prewarm()
            await vm.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .planning:
            VStack(alignment: .leading, spacing: 8) {
                ProgressView()
                Text("Planning…")
                    .foregroundStyle(.secondary)
            }

        case .generating(let partial):
            if let partial {
                DigestResultView(partial: partial)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    Text("Generating species digest…")
                        .foregroundStyle(.secondary)
                }
            }

        case .loaded(let partial):
            DigestResultView(partial: partial)

        case .failed(let error):
            VStack(alignment: .leading, spacing: 8) {
                Text("❌ Error")
                    .font(.headline)
                Text(error.errorDescription ?? "Unknown error")
                    .foregroundStyle(.red)
            }

        case .unavailable(let status):
            VStack(alignment: .leading, spacing: 8) {
                Text("⚠️ AI 功能無法使用")
                    .font(.headline)
                Text("狀態：\(String(describing: status))")
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
