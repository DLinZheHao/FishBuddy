//
//  SpeciesDigest.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/11.
//

import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct SpeciesDigest: Equatable, Codable {
    @Guide(description:
      """
      產出「中文」卡片標題，一句話說明這種魚最核心、最能辨識的點。
      規則：
      - 10~18 個中文字為主（可含少量常見英文，如 cm / IUCN）
      - 口語、直接、不要學術腔
      - 不要換行、不要列表符號、不要引號或括號
      - 標點只允許：， 。 ； （盡量不用）
      - 不要輸出任何 emoji、特殊符號（例如 • - — ~ / | [] {} <> ★）
      """
    )
    let titleZh: String

    @Guide(description:
      """
      三個「最容易用眼睛看出來」的辨識特徵（外觀/花紋/體型/特殊器官）。
      規則：
      - 必須剛好 3 點，每點 8~16 字
      - 用短句、用「可視覺化」描述（例：像枯葉、背鰭像鳳頭）
      - 不要提分佈/棲地/行為（那些放別欄位）
      - 不要換行、不要編號、不要項目符號
      - 不要括號、不要引號
      - 標點只允許：， 。
      """
    )
    @Guide(.count(3))
    let keyTraits: [String]

    @Guide(description:
      """
      棲地與分佈摘要（中文 1~2 句），只能根據輸入資料，不可推測或補充外部常識。
      規則：
      - 20~45 字
      - 用「在哪裡 + 什麼環境」的句型
      - 不要列點、不要括號、不要引號
      - 標點只允許：， 。
      """
    )
    let habitatSummary: String

    @Guide(description:
      """
      最容易混淆的點：教使用者「看哪裡」避免誤認（中文 1 句）。
      規則：
      - 若資料不足，輸出：unknown（全小寫）
      - 若有資料，字數 12~26 字
      - 句型建議：「容易和X混淆，看Y來分辨」
      - 不要括號、不要引號、不要列點
      - 標點只允許：， 。
      """
    )
    let confusionTip: String

    @Guide(description:
      """
      安全提醒（中文 0~1 句）。
      規則：
      - 若沒有任何風險/保育/不可觸碰資訊，輸出空字串 ""
      - 若有，字數 10~24 字，直接提醒（例：背鰭棘有毒，勿徒手觸碰）
      - 不要恐嚇語氣，不要誇大
      - 不要括號、不要引號、不要列點
      - 標點只允許：， 。
      """
    )
    let safetyNote: String

    @Guide(description:
      """
      coverage：列出本摘要「確實用到」哪些資料欄位。
      規則：
      - 只能從以下 token 選：taxonomy,basic_info,morphology,habitat_and_distribution,environment_and_depth,ecology_and_behavior,growth_and_life_history,conservation_and_human_uses,taiwan_and_regional_notes,reproduction,diet_and_behavior,benefits_and_uses
      - 用半形逗號連接（,），不要空格
      - 至少 1 個，最多 6 個
      - 若真的無法判斷，輸出：unknown
      - 不要任何其他字或符號
      """
    )
    let coverage: String
}
@available(iOS 26.0, *)
extension SpeciesDigest {
    // 一個「格式示例」：讓模型知道你要的 style（但禁止抄內容）
    static let exampleSpeciesDigest = SpeciesDigest(
        titleZh: "身側有明顯縱紋的礁區小型魚",
        keyTraits: [
            "身體細長，側邊有多條深色縱紋",
            "背鰭明顯豎起，輪廓清楚",
            "尾鰭分叉，邊緣形狀對稱"
        ],
        habitatSummary: "多分布於近岸淺海礁區，常見於珊瑚與岩礁周圍的水域。",
        confusionTip: "容易和其他條紋魚混淆，看縱紋清晰度與尾鰭形狀分辨。",
        safetyNote: "",
        coverage: "morphology,habitat_and_distribution"
    )

}

@available(iOS 26.0, *)
@Generable
struct DigestPlan: Equatable, Codable {
    @Guide(description: "Pick up to 3 focus areas that are most useful for a user-facing brief card.")
    @Guide(.count(3))
    let focus: [FocusArea]

    @Guide(description: "One short sentence explaining why these areas were chosen based only on the summary metadata.")
    let reason: String
}

@available(iOS 26.0, *)
@Generable
enum FocusArea: String, Codable, CaseIterable, Equatable {
    case basicInfo
    case morphology
    case habitatAndDistribution
    case taiwanAndRegionalNotes
    case distribution
    case dietAndBehavior
    case ecologyAndBehavior
    case environmentAndDepth
    case reproduction
    case conservationAndHumanUses
    case benefitsAndUses
    case growthAndLifeHistory
}

enum AIPromptEncoding {
    static func jsonString<T: Encodable>(_ value: T) -> String {
        do {
            let encoder = JSONEncoder()
            // ✅ 不使用 sortedKeys
            let data = try encoder.encode(value)
            return String(decoding: data, as: UTF8.self)
        } catch {
            return "<encode failed: \(error)>"
        }
    }

    static func jsonString<T: Encodable>(_ value: T?) -> String {
        guard let v = value else { return "nil" }
        return jsonString(v)
    }
}

@available(iOS 26.0, *)
struct TaxonFieldSummaryPrompt: PromptRepresentable {

    let taxon: TaxonItem

    var promptRepresentation: Prompt {
        Prompt {
            "Taxon field summary (metadata only):"

            "taxonId: \(taxon.taxonId)"
            "scientificName: \(taxon.scientificName)"
            "commonNameZh: \(taxon.commonNameZh ?? "nil")"

            // 只告訴它：有沒有資料（不要丟內容）
            "hasBasicInfo: \(taxon.basicInfo != nil)"
            "hasMorphology: \(taxon.morphology != nil)"
            "hasHabitatAndDistribution: \(taxon.habitatAndDistribution != nil)"
            "hasTaiwanNotes: \(taxon.taiwanAndRegionalNotes != nil)"
            "hasDistribution: \(taxon.distribution != nil)"
            "hasDietAndBehavior: \(taxon.dietAndBehavior != nil)"
            "hasEcologyAndBehavior: \(taxon.ecologyAndBehavior != nil)"
            "hasEnvironmentAndDepth: \(taxon.environmentAndDepth != nil)"
            "hasReproduction: \(taxon.reproduction != nil)"
            "hasConservationAndHumanUses: \(taxon.conservationAndHumanUses != nil)"
            "hasBenefitsAndUses: \(taxon.benefitsAndUses != nil)"
            "hasGrowthAndLifeHistory: \(taxon.growthAndLifeHistory != nil)"

            // fan-out: 只給 count（避免模型分心）
            "photosCount: \(taxon.photos.count)"
            "wikiPhotosCount: \(taxon.wikiPhotos.count)"
            "distributionLayersCount: \(taxon.distributionLayers.count)"
        }
    }
}

@available(iOS 26.0, *)
struct SelectedFieldsPrompt: PromptRepresentable {
    
    let taxon: TaxonItem
    let plan: DigestPlan

    var promptRepresentation: Prompt {
        Prompt {
            "Selected fields for summarization (JSON):"
            "scientificName: \(taxon.scientificName)"
            "commonNameZh: \(taxon.commonNameZh ?? "nil")"

            for area in plan.focus {
                sectionPrompt(for: area)
            }
            
            "Here is an example of the desired format, but don't copy its content:"
            SpeciesDigest.exampleSpeciesDigest
        }
    }

    private func sectionPrompt(for area: FocusArea) -> Prompt {
        switch area {
        case .basicInfo:
            return Prompt { "basicInfo: \(AIPromptEncoding.jsonString(taxon.basicInfo))" }
        case .morphology:
            return Prompt { "morphology: \(AIPromptEncoding.jsonString(taxon.morphology))" }
        case .habitatAndDistribution:
            return Prompt { "habitatAndDistribution: \(AIPromptEncoding.jsonString(taxon.habitatAndDistribution))" }
        case .taiwanAndRegionalNotes:
            return Prompt { "taiwanAndRegionalNotes: \(AIPromptEncoding.jsonString(taxon.taiwanAndRegionalNotes))" }
        case .distribution:
            return Prompt { "distribution: \(AIPromptEncoding.jsonString(taxon.distribution))" }
        case .dietAndBehavior:
            return Prompt { "dietAndBehavior: \(AIPromptEncoding.jsonString(taxon.dietAndBehavior))" }
        case .ecologyAndBehavior:
            return Prompt { "ecologyAndBehavior: \(AIPromptEncoding.jsonString(taxon.ecologyAndBehavior))" }
        case .environmentAndDepth:
            return Prompt { "environmentAndDepth: \(AIPromptEncoding.jsonString(taxon.environmentAndDepth))" }
        case .reproduction:
            return Prompt { "reproduction: \(AIPromptEncoding.jsonString(taxon.reproduction))" }
        case .conservationAndHumanUses:
            return Prompt { "conservationAndHumanUses: \(AIPromptEncoding.jsonString(taxon.conservationAndHumanUses))" }
        case .benefitsAndUses:
            return Prompt { "benefitsAndUses: \(AIPromptEncoding.jsonString(taxon.benefitsAndUses))" }
        case .growthAndLifeHistory:
            return Prompt { "growthAndLifeHistory: \(AIPromptEncoding.jsonString(taxon.growthAndLifeHistory))" }
        }
    }
}

@available(iOS 26.0, *)
enum SpeciesDigestInstructions {
    static let plan = Instructions {
        "You are planning which data fields to use to create a user-facing species brief card."
        "You will receive only metadata (hasX flags and counts), not the content."
        "Select up to 3 focus areas that will most likely produce a high-quality brief card."
        "Prefer morphology, habitatAndDistribution, taiwanAndRegionalNotes, basicInfo, distribution when available."
        "Ignore photos/wikiPhotos/distributionLayers; counts are informational only."
        "Return a DigestPlan that strictly conforms to the schema."
    }

    static let digest = Instructions {
        "You are FishBuddy's on-device assistant for summarizing species data."
        "Write in Traditional Chinese (zh-Hant)."
        "Use ONLY the provided selected fields. Do NOT guess."
        "If missing, output 'unknown' for that field."
        "Return a SpeciesDigest that strictly conforms to the schema."
        "Keep it concise and scannable for a UI card."
        "Prefer observable traits over taxonomy jargon."
        "For safetyNote: if no safety-related info is provided, return an empty string."
    }
}
