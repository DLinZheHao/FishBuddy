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
        fetchWeatherAPI()
    }

    private func fetchWeatherAPI() {
        var param = [String: Any]()
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

}
