//
//  UserHomeViewModel.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/25.
//

import Foundation
import Combine

@MainActor
final class UserHomeViewModel: ObservableObject {
    @Published var response: [RecognitionSessionDetail] = []
    @Published var taxonViewHistory: [TaxonViewHistoryDetail] = []
    @Published var errorMessage: String?

    func fetchRecognitionSessions(limit: Int = 50) async {
        do {
            response = try await UserStore.shared.fetchRecognitionSessions(limit: limit)
            errorMessage = nil
            print("成功： 成功取得識別紀錄 \(response.count)")
        } catch {
            response = []
            errorMessage = error.localizedDescription
            print("發生錯誤： \(error.localizedDescription)")
        }
    }

    func fetchTaxonViewHistory(limit: Int = 50) async {
        do {
            taxonViewHistory = try await UserStore.shared.fetchTaxonViewHistory(limit: limit)
            errorMessage = nil
            print("成功： 成功取得瀏覽紀錄 \(taxonViewHistory.count)")
        } catch {
            taxonViewHistory = []
            errorMessage = error.localizedDescription
            print("發生錯誤： \(error.localizedDescription)")
        }
    }
}
