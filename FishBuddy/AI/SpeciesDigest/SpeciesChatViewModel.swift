//
//  SpeciesChatViewModel.swift
//  FishBuddy
//

import Foundation
import Observation

/// 物種詳情頁的聊天室 view model；訊息以 `messages` 時間軸為單一資料來源。
///
/// 使用方式：
/// - View 進場：`.task { vm.prewarm(); await vm.bootstrap() }`
/// - 使用者提問：透過 `.task(id: tick) { await vm.ask(topic) }` 觸發；同畫面 tick 變動會
///   自動 cancel 上一條串流，cancelled 留在歷史顯示「已取消」。
@available(iOS 26.0, *)
@MainActor
@Observable
final class SpeciesChatViewModel {

    // MARK: - Models

    enum MessageRole: Equatable {
        case assistant
        case user
    }

    /// 一則訊息的內容；`thinking` 是 stream 開始但還沒收到第一個 partial 時的暫填值。
    enum MessageContent: Equatable {
        case userText(String)
        case digest(SpeciesDigest.PartiallyGenerated)
        case answer(SpeciesAnswer.PartiallyGenerated)
        /// Phase 1 plan 判定無資料；不進 Phase 2，view 直接渲染 noDataView。
        case noDataAnswer
        case thinking
        case info(String)
        case error(String)
        /// 串流被中斷；保留最後一次拿到的 partial（可能是 nil）
        case cancelled(SpeciesAnswer.PartiallyGenerated?)
    }

    struct ChatMessage: Identifiable, Equatable {
        let id: UUID
        let role: MessageRole
        var content: MessageContent
        var isStreaming: Bool
        let topic: QuestionTopic?
        let createdAt: Date
    }

    // MARK: - Public state

    private(set) var messages: [ChatMessage] = []
    private(set) var unavailable: FoundationModelAvailabilityStore.Status?

    /// 顯示在 chat top bar 的標題；中文俗名優先，沒有則退到學名。
    var title: String {
        if let zh = taxon.commonNameZh, !zh.isEmpty {
            return zh
        }
        return taxon.scientificName
    }

    // MARK: - Private

    private let taxon: TaxonItem

    init(taxon: TaxonItem) {
        self.taxon = taxon
    }

    // MARK: - API

    func prewarm() {
        SpeciesDigestService.shared.prewarm()
    }

    /// 一進畫面呼叫；冪等：messages 已有資料就直接 return（避免 SwiftUI .task 重觸發二次加載）。
    func bootstrap() async {
        guard messages.isEmpty else { return }

        // Cache hit：直接放完成的 digest bubble，不需要 thinking placeholder
        if let cached = SpeciesDigestService.shared.cachedDigest(for: taxon.taxonId) {
            appendAssistant(.digest(cached), topic: nil, streaming: false)
            return
        }

        let placeholderId = appendAssistant(.thinking, topic: nil, streaming: true)

        do {
            let stream = SpeciesDigestService.shared.digestStream(for: taxon)
            for try await event in stream {
                switch event {
                case .planReady:
                    break  // 對使用者不可見
                case .digestPartial(let partial):
                    update(id: placeholderId, content: .digest(partial), streaming: true)
                case .digestComplete(let final):
                    update(id: placeholderId, content: .digest(final), streaming: false)
                }
            }
        } catch let error as SpeciesDigestService.DigestError {
            switch error {
            case .unavailable(let status):
                unavailable = status
                update(id: placeholderId,
                       content: .info("AI 功能無法使用（\(status)）"),
                       streaming: false)
            case .cancelled:
                // bootstrap 被 cancel 通常是 view disappear；移除 placeholder 不留痕
                remove(id: placeholderId)
            default:
                update(id: placeholderId,
                       content: .error(error.errorDescription ?? "Unknown error"),
                       streaming: false)
            }
        } catch {
            update(id: placeholderId,
                   content: .error(error.localizedDescription),
                   streaming: false)
        }
    }

    /// 使用者提一個問題；append user bubble + streaming assistant bubble。
    /// 取消會把 assistant bubble 轉成 `.cancelled(lastPartial)` 留在歷史中。
    func ask(_ topic: QuestionTopic) async {
        appendUser(.userText(topic.displayName), topic: topic)
        let assistantId = appendAssistant(.thinking, topic: topic, streaming: true)

        var lastPartial: SpeciesAnswer.PartiallyGenerated?
        do {
            let stream = SpeciesDigestService.shared.answerStream(for: taxon, topic: topic)
            for try await event in stream {
                switch event {
                case .planReady:
                    break  // 對使用者不可見
                case .answerNoData:
                    update(id: assistantId, content: .noDataAnswer, streaming: false)
                case .answerPartial(let partial):
                    lastPartial = partial
                    update(id: assistantId, content: .answer(partial), streaming: true)
                case .answerComplete(let final):
                    lastPartial = final
                    update(id: assistantId, content: .answer(final), streaming: false)
                }
            }
        } catch let error as SpeciesDigestService.DigestError {
            switch error {
            case .unavailable(let status):
                unavailable = status
                update(id: assistantId,
                       content: .info("AI 功能無法使用（\(status)）"),
                       streaming: false)
            case .cancelled:
                update(id: assistantId, content: .cancelled(lastPartial), streaming: false)
            default:
                update(id: assistantId,
                       content: .error(error.errorDescription ?? "Unknown error"),
                       streaming: false)
            }
        } catch {
            update(id: assistantId,
                   content: .error(error.localizedDescription),
                   streaming: false)
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func appendAssistant(
        _ content: MessageContent,
        topic: QuestionTopic?,
        streaming: Bool
    ) -> UUID {
        let msg = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: content,
            isStreaming: streaming,
            topic: topic,
            createdAt: .now
        )
        messages.append(msg)
        return msg.id
    }

    @discardableResult
    private func appendUser(_ content: MessageContent, topic: QuestionTopic?) -> UUID {
        let msg = ChatMessage(
            id: UUID(),
            role: .user,
            content: content,
            isStreaming: false,
            topic: topic,
            createdAt: .now
        )
        messages.append(msg)
        return msg.id
    }

    private func update(id: UUID, content: MessageContent, streaming: Bool) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].content = content
        messages[idx].isStreaming = streaming
    }

    private func remove(id: UUID) {
        messages.removeAll { $0.id == id }
    }
}
