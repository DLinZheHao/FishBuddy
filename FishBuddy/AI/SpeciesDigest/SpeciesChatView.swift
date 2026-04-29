//
//  SpeciesChatView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/11.
//

import SwiftUI

@available(iOS 26.0, *)
struct SpeciesChatView: View {

    @State var vm: SpeciesChatViewModel

    @State private var freeText: String = ""
    @State private var pendingTopic: QuestionTopic?
    @State private var askTick: Int = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cwSurface.ignoresSafeArea()

            messagesScroll
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ChatTopBar(title: vm.title) { dismiss() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                QuickReplyBar { topic in fire(topic: topic) }
                InputBar(
                    text: $freeText,
                    placeholder: "問這隻魚的特徵或習性…",
                    onSend: fireFree
                )
            }
            .background(Color.cwSurfaceLow)
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

    // MARK: - Messages list

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: vm.messages.last?.isStreaming) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = vm.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Actions

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

// MARK: - Top bar

@available(iOS 26.0, *)
private struct ChatTopBar: View {

    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 44, height: 36)

            Spacer()

            VStack(spacing: 0) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.cwOnSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("AI 助手")
                    .font(.caption2)
                    .foregroundStyle(Color.cwOnSurfaceVar)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cwOnSurface)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.cwSurfaceHigh))
            }
            .padding(.trailing, 12)
            .accessibilityLabel("關閉")
        }
        .padding(.vertical, 10)
        .background(Color.cwSurfaceLow)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }
}

// MARK: - Message bubble dispatcher

@available(iOS 26.0, *)
private struct MessageBubble: View {

    let message: SpeciesChatViewModel.ChatMessage

    var body: some View {
        switch message.content {
        case .info(let text):
            HStack {
                Spacer(minLength: 0)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(Color.cwOnSurfaceVar)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.cwSurfaceHigh.opacity(0.6))
                    )
                Spacer(minLength: 0)
            }

        case .userText(let text):
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 40)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.cwPrimary)
                    )
            }

        default:
            HStack(alignment: .top, spacing: 0) {
                AssistantBubble(tone: tone) {
                    assistantContent
                }
                Spacer(minLength: 40)
            }
        }
    }

    @ViewBuilder
    private var assistantContent: some View {
        switch message.content {
        case .digest(let partial):
            DigestBubbleContent(partial: partial, isStreaming: message.isStreaming)
        case .answer(let partial):
            AnswerBubbleContent(
                partial: partial,
                topic: message.topic,
                isStreaming: message.isStreaming
            )
        case .thinking:
            ThinkingIndicator()
        case .error(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(Color.cwError)
        case .cancelled(let lastPartial):
            CancelledBubbleContent(partial: lastPartial)
        case .info, .userText:
            EmptyView()
        }
    }

    private var tone: BubbleTone {
        switch message.content {
        case .error:     return .error
        case .cancelled: return .muted
        default:         return .normal
        }
    }
}

// MARK: - Assistant bubble container

private enum BubbleTone { case normal, error, muted }

@available(iOS 26.0, *)
private struct AssistantBubble<Content: View>: View {

    let tone: BubbleTone
    @ViewBuilder let content: () -> Content

    init(tone: BubbleTone = .normal, @ViewBuilder content: @escaping () -> Content) {
        self.tone = tone
        self.content = content
    }

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: tone == .error ? 1 : 0)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var background: Color {
        switch tone {
        case .normal: return .cwSurfaceLowest
        case .error:  return .cwSurfaceLowest
        case .muted:  return .cwSurfaceLow
        }
    }

    private var border: Color {
        switch tone {
        case .error: return Color.cwError.opacity(0.4)
        default:     return .clear
        }
    }
}

// MARK: - Digest bubble (formatted species card)

@available(iOS 26.0, *)
private struct DigestBubbleContent: View {

    let partial: SpeciesDigest.PartiallyGenerated
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("物種速覽", systemImage: "fish.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cwPrimary)

            if let title = partial.titleZh, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.cwOnSurface)
            }

            if let traits = partial.keyTraits, !traits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(traits.enumerated()), id: \.offset) { _, trait in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•").foregroundStyle(Color.cwPrimary)
                            Text(trait).foregroundStyle(Color.cwOnSurface)
                        }
                        .font(.subheadline)
                    }
                }
            }

            field(label: "棲地", value: partial.habitatSummary)
            field(label: "辨識重點", value: partial.confusionTip)
            field(label: "安全提醒", value: partial.safetyNote)

            if isStreaming {
                StreamingCursor()
            }
        }
    }

    @ViewBuilder
    private func field(label: String, value: String?) -> some View {
        if let value, !value.isEmpty, value != "unknown" {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.cwOnSurfaceVar)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.cwOnSurface)
            }
        }
    }
}

// MARK: - Answer bubble (Q&A response)

@available(iOS 26.0, *)
private struct AnswerBubbleContent: View {

    let partial: SpeciesAnswer.PartiallyGenerated
    let topic: QuestionTopic?
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let topic {
                Text("Q：\(topic.displayName)")
                    .font(.caption)
                    .foregroundStyle(Color.cwOnSurfaceVar)
            }

            if partial.noData == true {
                Label("此問題的資料未涵蓋", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cwTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(partial.text ?? "")
                    .font(.body)
                    .foregroundStyle(Color.cwOnSurface)
                    .textSelection(.enabled)

                if isStreaming {
                    StreamingCursor()
                        .padding(.leading, 2)
                }
            }
        }
    }
}

// MARK: - Cancelled bubble

@available(iOS 26.0, *)
private struct CancelledBubbleContent: View {

    let partial: SpeciesAnswer.PartiallyGenerated?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("已取消", systemImage: "xmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cwOnSurfaceVar)

            if let text = partial?.text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.cwOnSurfaceVar)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Thinking indicator (animated dots)

@available(iOS 26.0, *)
private struct ThinkingIndicator: View {

    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.cwPrimary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1.0 : 0.3)
            }
        }
        .frame(height: 16)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Streaming cursor

@available(iOS 26.0, *)
private struct StreamingCursor: View {

    @State private var visible = true

    var body: some View {
        Text("▍")
            .font(.body)
            .foregroundStyle(Color.cwPrimary)
            .opacity(visible ? 1 : 0.2)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    visible.toggle()
                }
            }
    }
}

// MARK: - Quick reply bar

@available(iOS 26.0, *)
private struct QuickReplyBar: View {

    let onTap: (QuestionTopic) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(QuestionTopic.chipTopics.enumerated()), id: \.offset) { _, topic in
                    Button {
                        onTap(topic)
                    } label: {
                        Text(topic.displayName)
                    }
                    .buttonStyle(QuickReplyChipStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

@available(iOS 26.0, *)
private struct QuickReplyChipStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.cwPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(configuration.isPressed ? Color.cwSecContainer : Color.cwSurfaceLowest)
            )
            .overlay(
                Capsule().stroke(Color.cwPrimary.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Input bar

@available(iOS 26.0, *)
private struct InputBar: View {

    @Binding var text: String
    let placeholder: String
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholder, text: $text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.cwSurfaceLowest)
                )
                .submitLabel(.send)
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(isDisabled ? Color.cwSurfaceHigh : Color.cwPrimary)
                    )
            }
            .disabled(isDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var isDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Design tokens (mirrored from CityWeatherView)
// 後續若要共用，可抽到 FishBuddy/Componet/DesignTokens.swift

private extension Color {
    static let cwPrimary        = Color(red: 0.000, green: 0.396, blue: 0.463) // #006576
    static let cwTertiary       = Color(red: 0.620, green: 0.239, blue: 0.000) // #9e3d00
    static let cwSurface        = Color(red: 0.976, green: 0.976, blue: 0.984) // #f9f9fb
    static let cwSurfaceLow     = Color(red: 0.953, green: 0.953, blue: 0.961) // #f3f3f5
    static let cwSurfaceLowest  = Color.white
    static let cwSurfaceHigh    = Color(red: 0.910, green: 0.910, blue: 0.918) // #e8e8ea
    static let cwOnSurface      = Color(red: 0.102, green: 0.110, blue: 0.114) // #1a1c1d
    static let cwOnSurfaceVar   = Color(red: 0.255, green: 0.278, blue: 0.333) // #414755
    static let cwSecContainer   = Color(red: 0.753, green: 0.902, blue: 0.925) // #c0e6ec
    static let cwError          = Color(red: 0.729, green: 0.102, blue: 0.102) // #ba1a1a
}
