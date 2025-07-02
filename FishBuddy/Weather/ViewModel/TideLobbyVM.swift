//
//  TideLobbyVM.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/7/2.
//

import Foundation
import Combine
import SwiftUI

class TideLobbyVM: ObservableObject {
    // 綁訂事件
    var cancellables = Set<AnyCancellable>()
    /// 預設查詢的城市
    @AppStorage("TideCity") private var tideCity: String = "" // swiftUI 使用 userDefault 的方式
    /// 近一個月的城市潮水資料
    @Published var tideResponse: TideDataModel?
    
    /// 測試呼叫潮汐 API
    func fetchTideAPI() {
        var param = [String: Any]()
        // 只需要放入地點其餘後端 app-api 會處理
        param["location"] = tideCity
        let target = WeatherAPIService.tideForecast.init(params: param)
        
        /// 接收範例
        APIService.shareManager().requestDataCombine(target: target)
            .handleEvents(receiveOutput: { _ in
                // 移除載入動畫
            })
            .tryMap { (data: Any?) -> Data in
                guard let data = data as? Data else {
                    throw NSError(domain: "InvalidData", code: 0, userInfo: nil)
                }
                return data
            }
            .decode(type: TideDataModel.self, decoder: JSONDecoder())
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Request failed with error: \(error.localizedDescription)")
                }
            }, receiveValue: { (model: TideDataModel) in
                self.tideResponse = model
            })
            .store(in: &cancellables)
    }

}
