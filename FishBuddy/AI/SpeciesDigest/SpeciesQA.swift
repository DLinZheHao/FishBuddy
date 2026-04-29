//
//  SpeciesQA.swift
//  FishBuddy
//

import Foundation
import FoundationModels

// MARK: - SpeciesAnswer schema

@available(iOS 26.0, *)
@Generable
struct SpeciesAnswer: Equatable, Codable {

    @Guide(description:
      """
      若提供的「資料欄位」完全沒有涵蓋這個問題的答案，設為 true；
      只要有一點相關資訊（即使不完整）就設 false。
      """
    )
    let noData: Bool

    @Guide(description:
      """
      以繁體中文回覆使用者的問題。
      規則：
      - 2~4 句，總長度 50~140 字
      - 必須只根據提供的資料欄位作答，不可推測或補外部常識
      - 若 noData 為 true，固定輸出「資料中未涵蓋這個問題」，不要多寫
      - 不要 emoji、不要列點、不要引號或括號
      - 標點只允許：， 。 ；
      """
    )
    let text: String
}

// MARK: - QuestionTopic

@available(iOS 26.0, *)
enum QuestionTopic: Equatable {
    case appearance
    case habitat
    case behavior
    case conservationUse
    case growth
    case free(String)

    /// chips 顯示用的中文名
    var displayName: String {
        switch self {
        case .appearance:       return "外觀特徵"
        case .habitat:          return "棲息環境"
        case .behavior:         return "食性與行為"
        case .conservationUse:  return "保育與利用"
        case .growth:           return "體型成長"
        case .free(let q):      return q
        }
    }

    /// 餵給模型的問題語句
    var question: String {
        switch self {
        case .appearance:       return "這個物種的外觀有哪些值得注意的辨識特徵？"
        case .habitat:          return "這個物種主要棲息在什麼環境？常出現在哪些區域？"
        case .behavior:         return "這個物種的食性與日常行為是什麼？"
        case .conservationUse:  return "這個物種的保育狀況如何？人類有哪些利用方式？"
        case .growth:           return "這個物種的體型大小與生長習性如何？"
        case .free(let q):      return q
        }
    }

    /// 對應要餵入 prompt 的 TaxonItem 欄位
    var fields: [FocusArea] {
        switch self {
        case .appearance:
            return [.morphology]
        case .habitat:
            return [.habitatAndDistribution, .environmentAndDepth, .taiwanAndRegionalNotes]
        case .behavior:
            return [.dietAndBehavior, .ecologyAndBehavior]
        case .conservationUse:
            return [.conservationAndHumanUses, .benefitsAndUses]
        case .growth:
            return [.growthAndLifeHistory]
        case .free(let q):
            return SpeciesQAFieldRouter.fields(forFreeQuestion: q)
        }
    }

    /// chip 區塊顯示順序
    static let chipTopics: [QuestionTopic] = [
        .appearance, .habitat, .behavior, .conservationUse, .growth,
    ]
}

// MARK: - Free-form keyword router

@available(iOS 26.0, *)
enum SpeciesQAFieldRouter {

    /// 簡單關鍵字對應；命中即聯集對應欄位，沒有命中時 fallback。
    /// 後續可換成 ML / embedding-based 路由。
    static func fields(forFreeQuestion question: String) -> [FocusArea] {
        let q = question
        var hit: Set<FocusArea> = []

        let table: [(keywords: [String], areas: [FocusArea])] = [
            (["顏色", "花紋", "體色", "外觀", "長相", "樣子", "鱗", "鰭", "斑"],
             [.morphology]),
            (["棲息", "環境", "海域", "水深", "深度", "分布", "分佈", "台灣", "出現"],
             [.habitatAndDistribution, .environmentAndDepth, .taiwanAndRegionalNotes]),
            (["保育", "瀕危", "IUCN", "利用", "用途", "食用", "經濟", "商業", "養殖"],
             [.conservationAndHumanUses, .benefitsAndUses]),
            (["吃", "食性", "食物", "獵物", "行為", "活動", "習性", "群居"],
             [.dietAndBehavior, .ecologyAndBehavior]),
            (["體長", "體型", "成長", "壽命", "公分", "cm", "幾歲"],
             [.growthAndLifeHistory]),
            (["繁殖", "產卵", "卵", "幼魚", "孵"],
             [.reproduction]),
        ]

        for (keys, areas) in table where keys.contains(where: { q.contains($0) }) {
            hit.formUnion(areas)
        }

        if hit.isEmpty {
            return [.basicInfo, .morphology, .habitatAndDistribution]
        }
        return Array(hit)
    }
}

// MARK: - Prompt building blocks

@available(iOS 26.0, *)
struct SelectedFieldsForQAPrompt: PromptRepresentable {

    let taxon: TaxonItem
    let fields: [FocusArea]

    var promptRepresentation: Prompt {
        Prompt {
            "Selected fields for answering the user question (JSON):"
            "scientificName: \(taxon.scientificName)"
            "commonNameZh: \(taxon.commonNameZh ?? "nil")"

            for area in fields {
                sectionPrompt(for: area)
            }
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

// MARK: - Instructions

@available(iOS 26.0, *)
enum SpeciesQAInstructions {
    static let answer = Instructions {
        "You are FishBuddy's on-device assistant answering a single user question about a fish species."
        "Write in Traditional Chinese (zh-Hant)."
        "Use ONLY the provided selected fields. Do NOT guess or add outside knowledge."
        "If the selected fields do not cover the question at all, set noData to true and write the fixed Chinese fallback text."
        "If only partial info is available, answer what you can and stay honest about the gap."
        "Return a SpeciesAnswer that strictly conforms to the schema."
        "Keep the tone neutral and informative; no marketing or alarmist phrasing."
    }
}
