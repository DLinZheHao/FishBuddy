//
//  SpeciesDigestService.swift
//  FishBuddy
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// 物種摘要產生服務（長期存在的 singleton）。
///
/// 使用方式：
/// ```swift
/// for try await event in SpeciesDigestService.shared.digestStream(for: taxon) {
///     switch event { ... }
/// }
/// ```
/// 取消（caller break out 或 Task cancel）會自動取消內部 plan/digest 工作。
@available(iOS 26.0, *)
final class SpeciesDigestService {

    // MARK: Public types

    enum Event {
        /// Phase 1 完成：模型決定使用哪些 focus areas
        case planReady(DigestPlan)
        /// Phase 2 streaming 中的部分結果（每個 token 更新都會發一次）
        case digestPartial(SpeciesDigest.PartiallyGenerated)
        /// Phase 2 結束的最後一個 snapshot；發完即 stream 正常 finish
        case digestComplete(SpeciesDigest.PartiallyGenerated)
    }

    enum AnswerEvent {
        /// Phase 1 完成；只供 debug／可被忽略
        case planReady(QAPlan)
        /// Phase 1 判定無資料可答；UI 直接顯示 noData，不會再有 partial/complete
        case answerNoData
        /// Phase 2 streaming 中的部分答案
        case answerPartial(SpeciesAnswer.PartiallyGenerated)
        /// Phase 2 streaming 結束的最後一個 snapshot
        case answerComplete(SpeciesAnswer.PartiallyGenerated)
    }

    enum DigestError: Error, LocalizedError {
        case unavailable(FoundationModelAvailabilityStore.Status)
        case planFailed(underlying: Error)
        case digestFailed(underlying: Error)
        case timeout
        case cancelled

        var errorDescription: String? {
            switch self {
            case .unavailable(let status):
                return "FoundationModels 目前不可用（\(status)）"
            case .planFailed(let underlying):
                return "規劃階段失敗：\(underlying.localizedDescription)"
            case .digestFailed(let underlying):
                return "摘要產生失敗：\(underlying.localizedDescription)"
            case .timeout:
                return "產生超時"
            case .cancelled:
                return "已取消"
            }
        }
    }

    // MARK: Singleton

    static let shared = SpeciesDigestService()

    // MARK: Cache

    private final class CachedEntry {
        let plan: DigestPlan
        let digest: SpeciesDigest.PartiallyGenerated
        init(plan: DigestPlan, digest: SpeciesDigest.PartiallyGenerated) {
            self.plan = plan
            self.digest = digest
        }
    }

    private let cache = NSCache<NSNumber, CachedEntry>()

    private init() {
        cache.countLimit = 50
    }

    // MARK: Public API

    /// 為指定 taxon 開啟一條 digest event stream。
    /// - Parameters:
    ///   - taxon: 目標物種
    ///   - timeout: 整體 budget；超過即 cancel 內部工作並拋 `.timeout`
    func digestStream(
        for taxon: TaxonItem,
        timeout: Duration = .seconds(60)
    ) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            // Cache hit：直接 replay 兩個ㄌ事件即 finish
            if let cached = self.cache.object(forKey: taxon.taxonId as NSNumber) {
                continuation.yield(.planReady(cached.plan))
                continuation.yield(.digestComplete(cached.digest))
                continuation.finish()
                return
            }

            let work = Task {
                do {
                    let status = await FoundationModelAvailabilityStore.shared.status
                    guard status == .available else {
                        throw DigestError.unavailable(status)
                    }
                    try await self.run(taxon: taxon, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: DigestError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            let timer = Task {
                try? await Task.sleep(for: timeout)
                guard !work.isCancelled else { return }
                work.cancel()
                continuation.finish(throwing: DigestError.timeout)
            }

            continuation.onTermination = { _ in
                work.cancel()
                timer.cancel()
            }
        }
    }

    /// 同步取得快取結果（沒命中回 nil）。供 UI 在進入畫面瞬間秀出舊資料用。
    func cachedDigest(for taxonId: Int) -> SpeciesDigest.PartiallyGenerated? {
        cache.object(forKey: taxonId as NSNumber)?.digest
    }

    func invalidateCache() {
        cache.removeAllObjects()
    }

    /// 預熱 on-device 模型引擎。建議在 app 啟動或進入相關畫面前呼叫一次。
    func prewarm() {
        LanguageModelSession(instructions: SpeciesDigestInstructions.plan).prewarm()
        LanguageModelSession(instructions: SpeciesDigestInstructions.digest).prewarm()
        LanguageModelSession(instructions: SpeciesQAInstructions.plan).prewarm()
        LanguageModelSession(instructions: SpeciesQAInstructions.answer).prewarm()
    }

    /// 為指定 taxon + topic 開啟一條單輪 Q&A stream。Q&A 不走 cache。
    func answerStream(
        for taxon: TaxonItem,
        topic: QuestionTopic,
        timeout: Duration = .seconds(60)
    ) -> AsyncThrowingStream<AnswerEvent, Error> {
        AsyncThrowingStream { continuation in
            let work = Task {
                do {
                    let status = await FoundationModelAvailabilityStore.shared.status
                    guard status == .available else {
                        throw DigestError.unavailable(status)
                    }
                    try await self.runAnswer(taxon: taxon, topic: topic, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: DigestError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            let timer = Task {
                try? await Task.sleep(for: timeout)
                guard !work.isCancelled else { return }
                work.cancel()
                continuation.finish(throwing: DigestError.timeout)
            }

            continuation.onTermination = { _ in
                work.cancel()
                timer.cancel()
            }
        }
    }

    // MARK: Private

    private func run(
        taxon: TaxonItem,
        continuation: AsyncThrowingStream<Event, Error>.Continuation
    ) async throws {
        // ──────────────── Phase 1: Plan ────────────────
        let plan: DigestPlan
        do {
            let session = LanguageModelSession(instructions: SpeciesDigestInstructions.plan)
            let prompt = Prompt {
                "Decide the best focus areas to generate a brief card."
                TaxonFieldSummaryPrompt(taxon: taxon)
            }
            let stream = session.streamResponse(
                to: prompt,
                generating: DigestPlan.self,
                includeSchemaInPrompt: false
            )
            plan = try await stream.collect().content
        } catch is CancellationError {
            throw DigestError.cancelled
        } catch {
            throw DigestError.planFailed(underlying: error)
        }
        try Task.checkCancellation()
        continuation.yield(.planReady(plan))

        // ──────────────── Phase 2: Digest ────────────────
        var lastSnapshot: SpeciesDigest.PartiallyGenerated?
        do {
            let session = LanguageModelSession(instructions: SpeciesDigestInstructions.digest)
            let prompt = Prompt {
                "Create a concise SpeciesDigest UI card."
                "Use only the selected fields below."
                "Plan focus: \(AIPromptEncoding.jsonString(plan))"
                SelectedFieldsPrompt(taxon: taxon, plan: plan)
            }
            let stream = session.streamResponse(
                to: prompt,
                generating: SpeciesDigest.self,
                includeSchemaInPrompt: false
            )
            for try await snapshot in stream {
                try Task.checkCancellation()
                let content = snapshot.content
                lastSnapshot = content
                continuation.yield(.digestPartial(content))
            }
        } catch is CancellationError {
            throw DigestError.cancelled
        } catch {
            throw DigestError.digestFailed(underlying: error)
        }

        guard let final = lastSnapshot else {
            throw DigestError.digestFailed(
                underlying: NSError(
                    domain: "SpeciesDigestService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Digest stream produced no snapshot"]
                )
            )
        }
        continuation.yield(.digestComplete(final))
        cache.setObject(
            CachedEntry(plan: plan, digest: final),
            forKey: taxon.taxonId as NSNumber
        )
    }

    private func runAnswer(
        taxon: TaxonItem,
        topic: QuestionTopic,
        continuation: AsyncThrowingStream<AnswerEvent, Error>.Continuation
    ) async throws {
        // ──────────────── 決定使用哪些欄位 ────────────────
        // chip：直接用 curated routing；free：走 Phase 1 LLM plan
        let fields: [FocusArea]
        switch topic {
        case .free:
            let plan = try await runQAPlan(taxon: taxon, topic: topic)
            continuation.yield(.planReady(plan))
            if plan.focus.isEmpty {
                continuation.yield(.answerNoData)
                return
            }
            fields = plan.focus
        default:
            // chip：用 QuestionTopic 自身的 curated routing
            fields = topic.routing.fields
        }

        // ──────────────── Phase 2: 生成答案 ────────────────
        var lastSnapshot: SpeciesAnswer.PartiallyGenerated?
        do {
            let session = LanguageModelSession(instructions: SpeciesQAInstructions.answer)
            let prompt = Prompt {
                "User question (Traditional Chinese): \(topic.question)"
                if topic.isCurated {
                    // chip 是 app 預先 curate 的題目，欄位也是親手挑的；告訴模型可以放心答。
                    // 否則 on-device 模型偏向過嚴判 noData，導致明明有資料卻拒答。
                    "Note: this question is one of the app's curated topics; the fields below have been pre-selected for this specific topic by the app. Trust the routing: if the fields contain ANY content addressing this topic (even partially or with caveats), provide an answer using the directly relevant parts. Set noData=true ONLY if the fields are genuinely empty or contain nothing related to the topic at all. Still avoid padding with unrelated facts."
                }
                SelectedFieldsForQAPrompt(taxon: taxon, fields: fields)
            }
            let stream = session.streamResponse(
                to: prompt,
                generating: SpeciesAnswer.self,
                includeSchemaInPrompt: false
            )
            for try await snapshot in stream {
                try Task.checkCancellation()
                let content = snapshot.content
                lastSnapshot = content
                continuation.yield(.answerPartial(content))
            }
        } catch is CancellationError {
            throw DigestError.cancelled
        } catch {
            throw DigestError.digestFailed(underlying: error)
        }

        guard let final = lastSnapshot else {
            throw DigestError.digestFailed(
                underlying: NSError(
                    domain: "SpeciesDigestService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Answer stream produced no snapshot"]
                )
            )
        }
        continuation.yield(.answerComplete(final))
    }

    /// Phase 1：呼叫 LLM 做 semantic field routing。
    /// Plan call 失敗時 fallback 到 keyword router 的結果。
    private func runQAPlan(
        taxon: TaxonItem,
        topic: QuestionTopic
    ) async throws -> QAPlan {
        do {
            let session = LanguageModelSession(instructions: SpeciesQAInstructions.plan)
            let prompt = Prompt {
                "User question (Traditional Chinese): \(topic.question)"
                QATaxonFieldDirectoryPrompt(taxon: taxon)
            }
            let stream = session.streamResponse(
                to: prompt,
                generating: QAPlan.self,
                includeSchemaInPrompt: false
            )
            let plan = try await stream.collect().content
            #if DEBUG
            print("🧭 [QAPlan] Q=\"\(topic.question)\" → focus=\(plan.focus.map { String(describing: $0) }), reason=\"\(plan.reason)\"")
            #endif
            return plan
        } catch is CancellationError {
            throw DigestError.cancelled
        } catch {
            // Plan 失敗：退回 keyword router，避免整個 Q&A 一起爆掉
            let routing = topic.routing
            #if DEBUG
            print("⚠️ [QAPlan] failed: \(error.localizedDescription) — fallback to keyword router fields=\(routing.fields)")
            #endif
            return QAPlan(focus: routing.fields, reason: "(plan-failed fallback)")
        }
    }
}
