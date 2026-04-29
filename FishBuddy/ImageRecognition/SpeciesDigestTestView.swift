//
//  SpeciesDigestTestView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/11.
//

import SwiftUI

/// commit A 的暫時 view：messages timeline 已就緒、但聊天室 UI 等 commit B 才會接上。
/// 這版只是把 vm.messages 用最樸素的方式列出，確保 timeline 流程能跑。
@available(iOS 26.0, *)
struct SpeciesDigestDebugView: View {

    @State var vm: SpeciesChatViewModel

    @State private var freeText: String = ""
    @State private var pendingTopic: QuestionTopic?
    @State private var askTick: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(vm.messages) { msg in
                        rawRow(msg)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            chipBar
            inputBar
        }
        .task {
            vm.prewarm()
            await vm.bootstrap()
        }
        .task(id: askTick) {
            guard askTick > 0, let topic = pendingTopic else { return }
            await vm.ask(topic)
        }
    }

    @ViewBuilder
    private func rawRow(_ msg: SpeciesChatViewModel.ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(roleLabel(msg.role))\(msg.isStreaming ? "  ▍" : "")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(describe(msg.content))
                .font(.body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roleLabel(_ role: SpeciesChatViewModel.MessageRole) -> String {
        switch role {
        case .assistant: return "[AI]"
        case .user:      return "[You]"
        }
    }

    private func describe(_ content: SpeciesChatViewModel.MessageContent) -> String {
        switch content {
        case .userText(let s):
            return s
        case .digest(let d):
            return [d.titleZh, d.keyTraits?.joined(separator: " / "), d.habitatSummary]
                .compactMap { $0 }
                .joined(separator: "\n")
        case .answer(let a):
            return a.text ?? ""
        case .thinking:
            return "（生成中…）"
        case .info(let s):
            return s
        case .error(let s):
            return "❌ \(s)"
        case .cancelled(let partial):
            return "（已取消）" + (partial?.text.map { "\n\($0)" } ?? "")
        }
    }

    // MARK: - Chips & Input (placeholder, will be redesigned in commit B)

    private var chipBar: some View {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("問這隻魚的特徵或習性…", text: $freeText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { fireFree() }
            Button("送出") { fireFree() }
                .disabled(trimmedFree.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        freeText = ""
    }
}
