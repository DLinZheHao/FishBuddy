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

    @State private var freeText: String = ""
    @State private var pendingTopic: QuestionTopic?
    @State private var askTick: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("🧪 Species Digest Test")
                    .font(.title2)
                    .bold()

                Divider()

                content

                Divider()

                qaSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            vm.prewarm()
            await vm.load()
        }
        .task(id: askTick) {
            guard askTick > 0, let topic = pendingTopic else { return }
            await vm.ask(topic)
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

    private var qaSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("提問")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(QuestionTopic.chipTopics.enumerated()), id: \.offset) { _, topic in
                        Button(topic.displayName) {
                            fire(topic: topic)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("自由提問…", text: $freeText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit { fireFree() }
                Button("送出") { fireFree() }
                    .disabled(trimmedFree.isEmpty)
            }

            answerView
        }
    }

    private var trimmedFree: String {
        freeText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fire(topic: QuestionTopic) {
        pendingTopic = topic
        askTick &+= 1
    }

    private func fireFree() {
        let q = trimmedFree
        guard !q.isEmpty else { return }
        fire(topic: .free(q))
    }

    @ViewBuilder
    private var answerView: some View {
        if let topic = vm.lastTopic {
            VStack(alignment: .leading, spacing: 6) {
                Text("Q：\(topic.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                answerBody(for: vm.answerState)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func answerBody(for state: SpeciesDigestViewModel.AnswerState) -> some View {
        switch state {
        case .idle:
            EmptyView()

        case .asking(let partial):
            if let partial, let text = partial.text, !text.isEmpty {
                Text(text)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("生成中…")
                        .foregroundStyle(.secondary)
                }
            }

        case .answered(let final):
            VStack(alignment: .leading, spacing: 4) {
                if final.noData == true {
                    Text("（資料未涵蓋）")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(final.text ?? "—")
                    .textSelection(.enabled)
            }

        case .failed(let error):
            Text(error.errorDescription ?? "Unknown error")
                .foregroundStyle(.red)
        }
    }
}

@available(iOS 26.0, *)
struct DigestResultView: View {

    let partial: SpeciesDigest.PartiallyGenerated

    var body: some View {
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
