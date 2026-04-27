//
//  FoundationModelAvailabilityStore.swift
//  FishBuddy
//

import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// App 級別的 Apple Intelligence / FoundationModels 可用性狀態，
/// 由 `AppDelegate` 啟動時 refresh，UI 直接讀取以決定要不要顯示 AI 功能或對應引導。
@MainActor
@Observable
final class FoundationModelAvailabilityStore {

    static let shared = FoundationModelAvailabilityStore()

    enum Status: Equatable {
        /// 還沒呼叫過 refresh，UI 應顯示 loading 或視為不可用
        case unknown
        /// 模型可用
        case available
        /// 系統版本低於 iOS 26
        case osTooOld
        /// 裝置硬體不支援 Apple Intelligence
        case deviceNotEligible
        /// 使用者尚未在「設定」開啟 Apple Intelligence
        case appleIntelligenceNotEnabled
        /// 模型尚未下載完成
        case modelNotReady
        /// 其他未列舉的不可用狀態（之後 SDK 新增的 case 落這裡）
        case unavailableOther
    }

    private(set) var status: Status = .unknown

    var isAvailable: Bool { status == .available }

    private init() {}

    func refresh() {
        if #available(iOS 26.0, *) {
            status = Self.resolveStatus()
        } else {
            status = .osTooOld
        }
    }

    @available(iOS 26.0, *)
    private static func resolveStatus() -> Status {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unavailableOther
        }
    }
}
