//
//  SpeciesDigestGenerator.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/1/11.
//

import Foundation
import FoundationModels
import Observation

@available(iOS 26.0, *)
@Observable
@MainActor
final class SpeciesDigestGenerator {

    var error: Error?
    let taxon: TaxonItem

    private let planSession: LanguageModelSession
    private let digestSession: LanguageModelSession

    private(set) var plan: DigestPlan?
    private(set) var speciesDigest: SpeciesDigest.PartiallyGenerated?

    init(taxon: TaxonItem) {
        self.taxon = taxon
        self.planSession = LanguageModelSession(instructions: SpeciesDigestInstructions.plan)
        self.digestSession = LanguageModelSession(instructions: SpeciesDigestInstructions.digest)
    }

    func prewarmModel() {
        planSession.prewarm()
        digestSession.prewarm()
    }

    /// Phase-1: generate plan
    func generatePlan() async {
        do {
            let prompt = Prompt {
                "Decide the best focus areas to generate a brief card."
                TaxonFieldSummaryPrompt(taxon: taxon)
            }

            let stream = planSession.streamResponse(
                to: prompt,
                generating: DigestPlan.self,
                includeSchemaInPrompt: false
            )

            let final = try await stream.collect().content
            self.plan = final

            // （可選）你也可以把 planPartial 直接設成 final 的部分鏡像用途
            // 但通常 Phase-1 不需要 partial UI
        } catch {
            self.error = error
        }
    }

    /// Phase-2: generate digest (requires plan)
    func generateDigest() async {
        do {
            guard let planValue = self.plan else {
                throw NSError(domain: "SpeciesDigestGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Plan not ready"])
            }

            let prompt = Prompt {
                "Create a concise SpeciesDigest UI card."
                "Use only the selected fields below."
                "Plan focus: \(AIPromptEncoding.jsonString(planValue))"
                SelectedFieldsPrompt(taxon: taxon, plan: planValue)
            }

            let stream = digestSession.streamResponse(
                to: prompt,
                generating: SpeciesDigest.self,
                includeSchemaInPrompt: false
            )

            for try await partial in stream {
                self.speciesDigest = partial.content
            }
        } catch {
            self.error = error
        }
    }

    /// Convenience: run both phases
    func generateAll() async {
        await generatePlan()
        await generateDigest()
    }
}
