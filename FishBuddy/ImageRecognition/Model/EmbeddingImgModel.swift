//
//  EmbeddingImgModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/1.
//

import Foundation
import SwiftUI

/// database 裡的資料
struct EmbeddingImgModel: Codable {
    /// 圖片標號
    @Default var id: String
    /// 圖片名稱
    @Default var name: String
    /// 圖片向量
    @Default var vector: [Float32]
}

/// 完整對應 JSON `items[]` 的資料結構（保持原樣 + 可選 embedding 欄位）
struct TaxonItem: Codable {
    
    @Default var taxonId: Int
    
    @Default var scientificName: String
    
    // flat json array
    let commonNameZh: String?
    
    // species 表中的 JSON 欄位（保留原始 JSON，避免過度解析）
    let taxonomy: Taxonomy?
    let basicInfo: BasicInfo?
    let morphology: Morphology?
    let dietAndBehavior: DietAndBehavior?
    let ecologyAndBehavior: EcologyAndBehavior?
    let habitatAndDistribution: HabitatAndDistribution?
    let environmentAndDepth: EnvironmentAndDepth?
    let reproduction: Reproduction?
    let conservationAndHumanUses: ConservationAndHumanUses?
    let benefitsAndUses: BenefitsAndUses?
    let taiwanAndRegionalNotes: TaiwanAndRegionalNotes?
    let distribution: Distribution?
    let embeddingMeta: EmbeddingMeta?
    let growthAndLifeHistory: GrowthAndLifeHistory?
    
    // fan-out 關聯表
    @Default var photos: [ResolvedPhoto]
    @Default var wikiPhotos: [ResolvedWikiPhoto]
    @Default var distributionLayers: [ResolvedDistributionLayer]
}

struct GrowthAndLifeHistory: Codable {
    @Default var maximumLengthCm: String
    @Default var growthNotes: String
    @Default var lifeHistoryNotes: String

    enum CodingKeys: String, CodingKey {
        case maximumLengthCm  = "maximum_length_cm"
        case growthNotes      = "growth_notes"
        case lifeHistoryNotes = "life_history_notes"
    }

    // ✅ 讓你可以手動 new（你剛剛那種寫法）
    init(maximumLengthCm: String, growthNotes: String, lifeHistoryNotes: String) {
        self._maximumLengthCm  = Default(wrappedValue: maximumLengthCm)
        self._growthNotes      = Default(wrappedValue: growthNotes)
        self._lifeHistoryNotes = Default(wrappedValue: lifeHistoryNotes)
    }
    
    // ✅ 手動初始化（Preview / fallback / 非 JSON 用）
    init() {
        self._maximumLengthCm = Default(wrappedValue: "")
        self._growthNotes = Default(wrappedValue: "")
        self._lifeHistoryNotes = Default(wrappedValue: "")
    }

    // ✅ JSON decode 用（處理 number / string 混用）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self._maximumLengthCm = Default(
            wrappedValue: container.decodeStringLossy(forKey: .maximumLengthCm)
        )

        self._growthNotes = Default(
            wrappedValue: (try? container.decode(String.self, forKey: .growthNotes)) ?? ""
        )

        self._lifeHistoryNotes = Default(
            wrappedValue: (try? container.decode(String.self, forKey: .lifeHistoryNotes)) ?? ""
        )
    }
}

struct TaiwanAndRegionalNotes: Codable {
    @Default var taiwanDistribution: String
    @Default var regionalEcologicalRole: String

    enum CodingKeys: String, CodingKey {
        case taiwanDistribution     = "taiwan_distribution"
        case regionalEcologicalRole = "regional_ecological_role"
    }
}

struct BenefitsAndUses: Codable {
    @Default var fisheryAndFood: String
    @Default var aquariumTrade: String
    @Default var ecologicalBenefits: String

    enum CodingKeys: String, CodingKey {
        case fisheryAndFood     = "fishery_and_food"
        case aquariumTrade      = "aquarium_trade"
        case ecologicalBenefits = "ecological_benefits"
    }
}

struct ConservationAndHumanUses: Codable {
    @Default var conservationStatus: String
    @Default var threats: String
    @Default var managementOrProtection: String

    enum CodingKeys: String, CodingKey {
        case conservationStatus = "conservation_status"
        case threats
        case managementOrProtection = "management_or_protection"
    }
}

struct Reproduction: Codable {
    @Default var reproductiveMode: String
    @Default var spawningBehavior: String
    @Default var parentalCare: String

    enum CodingKeys: String, CodingKey {
        case reproductiveMode = "reproductive_mode"
        case spawningBehavior = "spawning_behavior"
        case parentalCare     = "parental_care"
    }
}

struct EnvironmentAndDepth: Codable {
    @Default var environment: String
    @Default var depthRangeM: String

    enum CodingKeys: String, CodingKey {
        case environment
        case depthRangeM = "depth_range_m"
    }
}

struct Taxonomy: Codable {
    @Default var phylum: String
    @Default var classType: String
    @Default var order: String
    @Default var family: String
    @Default var genus: String
    
    enum CodingKeys: String, CodingKey {
        case phylum
        case classType = "class"
        case order
        case family
        case genus
    }
}
 
struct BasicInfo: Codable {
    @Default var summary: String
}

struct Morphology: Codable {
    @Default var bodyShape: String
    @Default var colorationAndPattern: String
    @Default var finsAndSpecialFeatures: String
    
    enum CodingKeys: String, CodingKey {
        case bodyShape = "body_shape"
        case colorationAndPattern = "coloration_and_pattern"
        case finsAndSpecialFeatures = "fins_and_special_features"
    }
}

struct DietAndBehavior: Codable {
    @Default var diet: String
    @Default var foragingBehavior: String
    
    enum CodingKeys: String, CodingKey {
        case diet
        case foragingBehavior = "foraging_behavior"
    }
}

struct EcologyAndBehavior: Codable {
    @Default var generalEcology: String
    @Default var socialStructure: String
    @Default var dailyRhythm: String
    
    enum CodingKeys: String, CodingKey {
        case generalEcology = "general_ecology"
        case socialStructure = "social_structure"
        case dailyRhythm = "daily_rhythm"
    }
}

struct HabitatAndDistribution: Codable {
    @Default var globalDistribution: String
    @Default var localHabitatType: String

    enum CodingKeys: String, CodingKey {
        case globalDistribution = "global_distribution"
        case localHabitatType   = "local_habitat_type"
    }
}

struct ResolvedPhoto: Codable, Sendable {
    let idx: Int
    let url: String
    let licenseCode: String?
    let attribution: String?
    let source: String?
}

struct ResolvedWikiPhoto: Codable, Sendable {
    let idx: Int
    let url: String
    let licenseCode: String?
    let license: String?
    let source: String?
    let attributionHTML: String?
}

extension ResolvedPhoto {
    func toUnifiedPhoto() -> UnifiedPhoto? {
        guard let u = URL(string: url) else { return nil }
        return UnifiedPhoto(
            idx: idx,
            url: u,
            licenseCode: licenseCode,
            licenseText: nil,
            attributionText: attribution,
            attributionHTML: nil,
            source: source,
            kind: .photo
        )
    }
}

extension ResolvedWikiPhoto {
    func toUnifiedPhoto() -> UnifiedPhoto? {
        guard let u = URL(string: url) else { return nil }
        return UnifiedPhoto(
            idx: idx,
            url: u,
            licenseCode: licenseCode,
            licenseText: license,
            attributionText: nil,          // 你也可以在這裡做 HTML->Text
            attributionHTML: attributionHTML,
            source: source,
            kind: .wiki
        )
    }
}

struct UnifiedPhoto: Sendable, Hashable {
    let idx: Int
    let url: URL
    let licenseCode: String?
    let licenseText: String?          // wiki 才有的 license（人類可讀）
    let attributionText: String?      // 統一成 text（必要時由 HTML 轉）
    let attributionHTML: String?      // 需要保留原始 HTML 就留
    let source: String?
    let kind: Kind

    enum Kind: Sendable, Hashable {
        case photo
        case wiki
    }
}


struct ResolvedDistributionLayer: Codable, Sendable {
    let idx: Int
    let layerKey: String
    let type: String?
    let url: String?
    let minZoom: Int?
    let maxZoom: Int?
    
    enum CodingKeys: String, CodingKey {
        case idx
        case layerKey = "layer_key"
        case type
        case url
        case minZoom
        case maxZoom
    }
}








struct UserPrompt: Codable, DefaultValue {
    static var defaultValue = UserPrompt(morphology: [], pattern: [], traits: [], habitat: [])
    /// 形態資料
    @Default var morphology: [String]
    /// 圖案
    @Default var pattern: [String]
    /// 特徵
    @Default var traits: [String]
    /// 棲息地
    @Default var habitat: [String]
    
    /// 檢查是不是資料都是空的
    var isEmpty: Bool {
        morphology.isEmpty && pattern.isEmpty && traits.isEmpty && habitat.isEmpty
    }
    
}

struct Photo: Codable {
    @Default var url: String
    let licenseCode: String?
    let attribution: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case url
        case licenseCode = "license_code"
        case attribution
        case source
    }
}

struct MetaData: Codable, DefaultValue {
    static var defaultValue = MetaData(wikipedia: nil)
    let wikipedia: WikipediaMeta?
}

struct WikipediaMeta: Codable {
    let title: String?
    let canonicalTitle: String?
    let extract: String?
    let url: String?
    let lang: String?
    let variant: String?
    let query: String?
    let strategy: String?
    let sections: Sections?

    enum CodingKeys: String, CodingKey {
        case title
        case canonicalTitle = "canonical_title"
        case extract
        case url
        case lang
        case variant
        case query
        case strategy
        case sections
    }
}

struct Sections: Codable {
    let distribution: String?
    let description: String?
    let ecology: String?
    let economicUse: String?

    enum CodingKeys: String, CodingKey {
        case distribution
        case description
        case ecology
        case economicUse = "economic_use"
    }
}

/// 寫入到 JSON 的 meta 摘要（保持你目前 embedIntoJSON 的鍵名）
struct EmbeddingMeta: Codable {
    @Default var model: String
    @Default var method: String
    @Default var cropScale: Double
    @Default var photosTotal: Int
    @Default var photosUsed: Int
    @Default var removed: Int
    @Default var dim: Int

    enum CodingKeys: String, CodingKey {
        case model
        case method
        case cropScale
        case photosTotal = "photos_total"
        case photosUsed = "photos_used"
        case removed
        case dim
    }
}

/// 物種分布（distribution）
struct Distribution: Codable {
    let type: String?
    let layers: [DistributionLayer]?
    let kmlURL: String?
    let places: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case layers
        case kmlURL = "kml_url"
        case places
    }
}

/// 物種分布圖層（distribution_layers）
struct DistributionLayer: Codable {
    let layerKey: String?
    let type: String?
    let url: String?
    let minzoom: Int?
    let maxzoom: Int?

    enum CodingKeys: String, CodingKey {
        case layerKey = "layer_key"
        case type
        case url
        case minzoom
        case maxzoom
    }
}

/// 搜尋結果
struct SearchResult {
    let id: String
    let score: Float
}


/// Minimal species row for list/search bootstrap (no heavy JSON / blobs).
struct SpeciesLite: Sendable {
    let taxonId: Int
    let scientificName: String
    let commonNameZh: String?
}

extension TaxonItem {

    // B'：英文名 chips（直接用 common_name_en）
    var displayENNames: [String] {
        []
    }

    // C：Quick Stats（完全不新增欄位，只做顯示層格式化）
    func makeQuickStats() -> [StatPillModel] {
        var out: [StatPillModel] = []

        // 1) SIZE
        if let cm = growthAndLifeHistory?.maximumLengthCm {
            out.append(.init(icon: "ruler", title: "SIZE", value: normalizeSize(cm), color: .blue))
        }

        // 2) DEPTH
        if let raw = environmentAndDepth?.depthRangeM, !raw.isEmpty {
            out.append(.init(icon: "arrow.down.to.line", title: "DEPTH", value: normalizeDepth(raw), color: .teal))
        }

        // 3) IUCN
        if let status = conservationAndHumanUses?.conservationStatus, !status.isEmpty {
            let code = extractIUCNCode(status) ?? status
            let isRisky = !(code.uppercased().contains("LC") || code.uppercased().contains("LEAST CONCERN"))
            out.append(.init(icon: "leaf", title: "IUCN", value: code, color: isRisky ? .red : .green))
        }

//        // 4) FAMILY（沒有就 GENUS）
//        if let family = taxonomy?.family, !family.isEmpty {
//            out.append(.init(icon: "point.3.connected.trianglepath.dotted", title: "FAMILY", value: family, color: .indigo))
//        } else if let genus = taxonomy?.genus, !genus.isEmpty {
//            out.append(.init(icon: "point.3.connected.trianglepath.dotted", title: "GENUS", value: genus, color: .indigo))
//        }

        return out
    }
    
    // MARK: - helpers（顯示層格式化，JSON 不動）

    private func normalizeDepth(_ raw: String) -> String {
        let text = raw.replacingOccurrences(of: "～", with: "-")
                      .replacingOccurrences(of: "—", with: "-")
                      .replacingOccurrences(of: "–", with: "-")

        // 擷取數字區間或單一數字
        let pattern = #"(\d+(?:\.\d+)?)(?:\s*-\s*(\d+(?:\.\d+)?))?"#
        let regex = try? NSRegularExpression(pattern: pattern)

        guard
            let match = regex?.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
        else { return raw }

        let start = (text as NSString).substring(with: match.range(at: 1))
        let endRange = match.range(at: 2)

        if endRange.location != NSNotFound {
            let end = (text as NSString).substring(with: endRange)
            return "\(start)–\(end) m"
        } else {
            return "\(start) m"
        }
    }

    private func normalizeSize(_ raw: String) -> String {
        let text = raw.replacingOccurrences(of: "～", with: "-")
                      .replacingOccurrences(of: "—", with: "-")
                      .replacingOccurrences(of: "–", with: "-")

        // 抓「單一數字」或「數字區間」
        let pattern = #"(\d+(?:\.\d+)?)(?:\s*-\s*(\d+(?:\.\d+)?))?"#
        let regex = try? NSRegularExpression(pattern: pattern)

        guard
            let match = regex?.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
        else { return raw }

        let start = (text as NSString).substring(with: match.range(at: 1))
        let endRange = match.range(at: 2)

        if endRange.location != NSNotFound {
            let end = (text as NSString).substring(with: endRange)
            return "\(start)–\(end) cm"
        } else {
            return "\(start) cm"
        }
    }

    private func extractIUCNCode(_ text: String) -> String? {
        let upper = text.uppercased()

        let validCodes = ["LC", "NT", "VU", "EN", "CR", "DD", "NE", "EW", "EX"]

        for code in validCodes {
            // 確保是獨立代碼，不是單字的一部分
            let pattern = #"(?<![A-Z])\#(code)(?![A-Z])"#
            if upper.range(of: pattern, options: .regularExpression) != nil {
                return code
            }
        }
        return nil
    }
}
