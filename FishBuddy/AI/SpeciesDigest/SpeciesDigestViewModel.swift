//
//  SpeciesDigestViewModel.swift
//  FishBuddy
//

import Foundation
import Observation

/// 單一畫面用的物種摘要狀態容器；接 `SpeciesDigestService` 的 stream，
/// 把事件轉成 UI 友善的 `State`。換 taxon 時應該整個重建（init 綁 taxon）。
///
/// 取消設計：
/// - `load()` 為 async；caller 應該從 SwiftUI 的 `.task { await vm.load() }` 呼叫。
/// - View 消失時 SwiftUI 自動 cancel 該 task scope，cancellation 會沿著
///   `await` 一路傳到 service 內部的 stream；無需自己管理 Task / deinit。
@available(iOS 26.0, *)
@MainActor
@Observable
final class SpeciesDigestViewModel {

    enum State {
        case idle
        case planning
        case generating(SpeciesDigest.PartiallyGenerated?)
        case loaded(SpeciesDigest.PartiallyGenerated)
        case failed(SpeciesDigestService.DigestError)
        case unavailable(FoundationModelAvailabilityStore.Status)
    }

    private(set) var state: State = .idle
    private(set) var plan: DigestPlan?

    private let taxon: TaxonItem

    init(taxon: TaxonItem) {
        self.taxon = taxon
    }

    /// 在 SwiftUI `.task { await vm.load() }` 內呼叫。
    /// View 消失時的 cancellation 會自動沿 `await` 傳到 service stream。
    func load() async {
        // 同步 cache 捷徑：避免 UI 在已快取時還閃一下 planning 狀態
        if let cached = SpeciesDigestService.shared.cachedDigest(for: taxon.taxonId) {
            state = .loaded(cached)
            return
        }

        state = .planning
        await run()
    }

    func prewarm() {
        SpeciesDigestService.shared.prewarm()
    }

    private func run() async {
        do {
            let stream = SpeciesDigestService.shared.digestStream(for: taxon)
            for try await event in stream {
                switch event {
                case .planReady(let p):
                    plan = p
                    state = .generating(nil)
                case .digestPartial(let partial):
                    state = .generating(partial)
                case .digestComplete(let final):
                    state = .loaded(final)
                }
            }
        } catch let error as SpeciesDigestService.DigestError {
            switch error {
            case .unavailable(let status):
                state = .unavailable(status)
            case .cancelled:
                // 結構化取消：view 消失等情境，靜默處理，不污染 state
                break
            default:
                state = .failed(error)
            }
        } catch {
            state = .failed(.digestFailed(underlying: error))
        }
    }
}
