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
      若資料欄位中沒有可以直接回答問題的事實，設為 true。
      即使資料有相關背景（棲地、體型、分布），只要無法直接回答提問本身
      （例如毒性、味道、寄生蟲），仍設為 true。
      只有資料明確涵蓋問題核心時，才設為 false。
      """
    )
    let noData: Bool

    @Guide(description:
      """
      以繁體中文分段回覆使用者的問題；陣列中每個元素是「一段」自成段落的文字。
      - 共 1~3 段；第 1 段先給結論。
      - 段內不要換行符、不要列點符號、不要 emoji。
      - 只根據提供的資料欄位作答，不推測。
      - 若 noData 為 true，輸出單一元素 ["資料中未涵蓋這個問題"]。
      """,
      .count(1...3)
    )
    let paragraphs: [String]
}

// MARK: - QuestionTopic

@available(iOS 26.0, *)
enum QuestionTopic: Equatable {
    case appearance
    case habitat
    case behavior
    case conservationUse
    case growth
    case toxicity
    case edibility
    case free(String)

    /// chips 顯示用的中文名
    var displayName: String {
        switch self {
        case .appearance:       return "外觀特徵"
        case .habitat:          return "棲息環境"
        case .behavior:         return "食性與行為"
        case .conservationUse:  return "保育與利用"
        case .growth:           return "體型成長"
        case .toxicity:         return "是否有毒"
        case .edibility:        return "是否可食"
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
        case .toxicity:         return "這個物種是否有毒？人類接觸或食用是否需要注意？"
        case .edibility:        return "這個物種是否可供人類食用？有什麼食用價值或注意事項？"
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
        case .toxicity:
            // 毒棘可能在外型；食用毒性警告在 benefits/fisheryAndFood
            return [.benefitsAndUses, .morphology]
        case .edibility:
            return [.benefitsAndUses]
        case .free(let q):
            return SpeciesQAFieldRouter.fields(forFreeQuestion: q)
        }
    }

    /// chip 區塊顯示順序
    static let chipTopics: [QuestionTopic] = [
        .appearance, .habitat, .behavior, .conservationUse, .growth,
        .toxicity, .edibility,
    ]

    /// 是否為 app 預先 curate 的 chip 題目；free 為使用者自由輸入
    var isCurated: Bool {
        switch self {
        case .free: return false
        default:    return true
        }
    }

    /// 完整的 routing 結果：fields + 路由模式
    /// 用來在 prompt 端決定要不要放「寬鬆 routing note」。
    var routing: SpeciesQARouting {
        switch self {
        case .appearance:
            return .init(fields: [.morphology], mode: .curated)
        case .habitat:
            return .init(fields: [.habitatAndDistribution, .environmentAndDepth, .taiwanAndRegionalNotes],
                         mode: .curated)
        case .behavior:
            return .init(fields: [.dietAndBehavior, .ecologyAndBehavior], mode: .curated)
        case .conservationUse:
            return .init(fields: [.conservationAndHumanUses, .benefitsAndUses], mode: .curated)
        case .growth:
            return .init(fields: [.growthAndLifeHistory], mode: .curated)
        case .toxicity:
            return .init(fields: [.benefitsAndUses, .morphology], mode: .curated)
        case .edibility:
            return .init(fields: [.benefitsAndUses], mode: .curated)
        case .free(let q):
            let r = SpeciesQAFieldRouter.route(freeQuestion: q)
            return .init(fields: r.fields, mode: r.wasHit ? .freeKeywordHit : .freeFallback)
        }
    }
}

// MARK: - Routing types

@available(iOS 26.0, *)
enum SpeciesQARoutingMode {
    /// chip 預先 curated 的題目
    case curated
    /// 自由輸入，且關鍵字命中對應 FocusArea
    case freeKeywordHit
    /// 自由輸入，但沒命中任何關鍵字，fallback 到通用欄位
    case freeFallback
}

@available(iOS 26.0, *)
struct SpeciesQARouting {
    let fields: [FocusArea]
    let mode: SpeciesQARoutingMode
}

// MARK: - Free-form keyword router

@available(iOS 26.0, *)
enum SpeciesQAFieldRouter {

    /// 路由結果；`wasHit` 表示有任何關鍵字命中（非 fallback）。
    static func route(freeQuestion question: String) -> (fields: [FocusArea], wasHit: Bool) {
        let q = question
        var hit: Set<FocusArea> = []

        let table: [(keywords: [String], areas: [FocusArea])] = [
            (["顏色", "花紋", "體色", "外觀", "長相", "樣子", "鱗", "鰭", "斑"],
             [.morphology]),
            (["棲息", "環境", "海域", "水深", "深度", "分布", "分佈", "台灣", "出現"],
             [.habitatAndDistribution, .environmentAndDepth, .taiwanAndRegionalNotes]),
            // 食用 / 利用：含各種「能不能吃」的 phrase；「吃」單字另外處理避免誤入飲食行為
            (["保育", "瀕危", "IUCN", "利用", "用途",
              "食用", "可食用", "可以食", "能食",
              "可吃", "可以吃", "能吃",
              "好吃", "難吃", "美味",
              "經濟", "商業", "養殖"],
             [.conservationAndHumanUses, .benefitsAndUses]),
            // 毒性、寄生蟲：魚類資料庫慣例放在「利用/食用」欄的注意事項；多開欄位反而吸引模型 padding
            (["毒", "有毒", "毒性", "毒棘", "寄生蟲", "中毒"],
             [.benefitsAndUses]),
            // 飲食行為：刻意不用單字「吃」，避免「可以吃」「好吃」誤命中；改用 phrase
            (["吃什麼", "吃啥", "捕食", "獵食",
              "食性", "食物", "獵物", "行為", "活動", "習性", "群居"],
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
            return (fields: [.basicInfo, .morphology, .habitatAndDistribution], wasHit: false)
        }
        return (fields: Array(hit), wasHit: true)
    }

    /// 舊呼叫位點保留：直接拿 fields。
    static func fields(forFreeQuestion question: String) -> [FocusArea] {
        route(freeQuestion: question).fields
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

// MARK: - QAPlan schema (Phase 1 of Q&A: semantic field routing)

/// Q&A 兩段式流程的第一階段輸出：模型自己挑出能直接回答問題的欄位。
/// `focus` 為空表示沒有任何欄位能直接回答 → 跳過 Phase 2 直接顯示 noData。
@available(iOS 26.0, *)
@Generable
struct QAPlan: Equatable, Codable {

    @Guide(description:
      """
      列出能「直接回答使用者問題」的 FocusArea。
      - 只能挑「Available 列表中標為有資料」的欄位
      - 若 Available 中沒有任何欄位能直接回答這個問題，回傳空陣列
      - 嚴格判斷：欄位內容必須能直接回答問題本身，不要因為主題相關就選
      - 通常 1~2 個就夠；最多 4 個
      """
    )
    @Guide(.count(0...4))
    let focus: [FocusArea]

    @Guide(description: "一句話（繁體中文，30 字內）說明選這些欄位的理由。")
    let reason: String
}

// MARK: - Field directory prompt (Phase 1 input)

/// 給 plan 階段使用：列出 12 個 FocusArea 的中文用途說明 + 該物種有哪些欄位有資料。
/// 不丟欄位內容（只給 metadata），讓模型專心做語意路由。
@available(iOS 26.0, *)
struct QATaxonFieldDirectoryPrompt: PromptRepresentable {

    let taxon: TaxonItem

    var promptRepresentation: Prompt {
        Prompt {
            "Field directory — match user question to phrasings in 『...』 FIRST:"
            "- basicInfo: 分類、學名、別名、基本背景"
            "- morphology: 『長什麼樣／怎麼分辨／有沒有毒棘／棘刺』；外型、體色、花紋、毒棘"
            "- habitatAndDistribution: 『住在哪／分布／什麼環境』；棲地類型、地理分布"
            "- taiwanAndRegionalNotes: 台灣與區域性註記"
            "- distribution: 詳細分布圖層"
            "- dietAndBehavior: 『牠吃什麼／吃什麼食物／怎麼獵食／食性是什麼』；魚自己進食的食物。NOT for『可以吃嗎／有毒嗎／好吃嗎』"
            "- ecologyAndBehavior: 生態、社交、活動模式"
            "- environmentAndDepth: 棲息水深、水溫、鹽度"
            "- reproduction: 繁殖、產卵、幼體"
            "- conservationAndHumanUses: 『保育狀況／是否瀕危／IUCN』；保育狀態、漁業管理"
            "- benefitsAndUses: 『可以吃嗎／是否可食用／能不能吃／有毒嗎／有沒有毒／毒性／好吃嗎／經濟價值／商業利用』；食用價值與警告（fisheryAndFood）、觀賞魚貿易"
            "- growthAndLifeHistory: 『體型多大／壽命／能長到幾公分』；成長、生活史"

            "Available fields for this species (only these have data):"
            "scientificName: \(taxon.scientificName)"
            "commonNameZh: \(taxon.commonNameZh ?? "nil")"
            "available: \(availableFieldsList)"
        }
    }

    private var availableFieldsList: String {
        var available: [String] = []
        if taxon.basicInfo != nil                  { available.append("basicInfo") }
        if taxon.morphology != nil                 { available.append("morphology") }
        if taxon.habitatAndDistribution != nil     { available.append("habitatAndDistribution") }
        if taxon.taiwanAndRegionalNotes != nil     { available.append("taiwanAndRegionalNotes") }
        if taxon.distribution != nil               { available.append("distribution") }
        if taxon.dietAndBehavior != nil            { available.append("dietAndBehavior") }
        if taxon.ecologyAndBehavior != nil         { available.append("ecologyAndBehavior") }
        if taxon.environmentAndDepth != nil        { available.append("environmentAndDepth") }
        if taxon.reproduction != nil               { available.append("reproduction") }
        if taxon.conservationAndHumanUses != nil   { available.append("conservationAndHumanUses") }
        if taxon.benefitsAndUses != nil            { available.append("benefitsAndUses") }
        if taxon.growthAndLifeHistory != nil       { available.append("growthAndLifeHistory") }
        return available.isEmpty ? "(none)" : available.joined(separator: ", ")
    }
}

// MARK: - Instructions

@available(iOS 26.0, *)
enum SpeciesQAInstructions {

    /// Phase 1：把使用者問題路由到對應 FocusArea。
    static let plan = Instructions {
        "You route a Traditional Chinese user question about a fish to the relevant data fields."
        "Each directory entry starts with question phrasings in 『...』. Match the user's question to those phrasings."
        "CRITICAL: distinguish 『可以吃嗎/有毒嗎/好吃嗎』(human-eating-fish) from 『牠吃什麼』(fish-eating-prey)."
        "  - Human-eating-fish → benefitsAndUses (NEVER dietAndBehavior)"
        "  - Fish-eating-prey → dietAndBehavior"
        "Worked examples:"
        "  Q='有毒嗎' → focus=[benefitsAndUses, morphology] (毒性可能在食用警告或毒棘描述; pick whichever are Available)"
        "  Q='可以吃嗎' / '能不能吃' / '好吃嗎' → focus=[benefitsAndUses]"
        "  Q='牠吃什麼' / '吃什麼食物' → focus=[dietAndBehavior]"
        "  Q='棲息在哪' → focus=[habitatAndDistribution]"
        "  Q='保育狀況' → focus=[conservationAndHumanUses]"
        "ONLY pick fields in the Available list; never invent."
        "If no Available field's phrasings match, return focus=[]."
        "Usually 1-2 fields; at most 4."
        "Return a QAPlan that strictly conforms to the schema."
    }

    /// Phase 2：根據選定欄位寫答案。
    static let answer = Instructions {
        "You are FishBuddy's on-device assistant answering one user question about a fish species in Traditional Chinese."
        "Use ONLY the provided fields; do not guess or add outside knowledge."
        "Answer the user's specific question only. Ignore fields that do not directly address it; do not pad with unrelated facts."
        "If the data lacks a direct answer to the specific question, set noData=true and return paragraphs as [\"資料中未涵蓋這個問題\"]."
        "Otherwise, write 1-3 short paragraphs in `paragraphs`; first paragraph gives the conclusion, follow-ups add only directly-relevant detail."
        "Tone: neutral and informative."
    }
}
