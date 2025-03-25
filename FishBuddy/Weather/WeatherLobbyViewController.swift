//
//  WeatherLobbyViewController.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import UIKit
import Combine

class WeatherLobbyViewController: UIViewController {

    // viewModel
    var vm = WeatherLobbyVM()
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        fetchWeatherAPI()
        fetchTideAPI()
    }

    /// 測試呼叫天氣 API
    private func fetchWeatherAPI() {
        let param = [String: Any]()
        let target = WeatherAPIService.weatherAll36.init(params: param)
        
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
            .decode(type: WeatherAllModel.self, decoder: JSONDecoder())
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Request failed with error: \(error.localizedDescription)")
                }
            }, receiveValue: { (model: WeatherAllModel) in
                print("成功")
            })
            .store(in: &vm.cancellables)
    }

    /// 測試呼叫潮汐 API
    private func fetchTideAPI() {
        var param = [String: Any]()
        // 只需要放入地點其餘後端 app-api 會處理
        param["location"] = "宜蘭"
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
                print("成功")
            })
            .store(in: &vm.cancellables)
    }
}
