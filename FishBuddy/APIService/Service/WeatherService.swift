//
//  WeatherService.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/5.
//

import Foundation
import Moya

protocol WeatherAPITargetType: TargetType {}

extension WeatherAPITargetType {
    var baseURL: URL {
        return APIBaseURLConfig.weatherBaseURL
    }
    var headers: [String: String]? { return nil }
    // 這個是做單元測試模擬的數據，必須要實現，只在單元測試文件中有作用
    var sampleData: Data {
        return "{}".data(using: String.Encoding.utf8)!
    }
}

enum WeatherAPIService {

    // MARK: 一般天氣預報 - 今明 36 小時天氣預報
    struct weatherAll36: WeatherAPITargetType {
        var method: Moya.Method { return .get }
        var path: String { return "F-C0032-001" }
        var task: Task {
            var params = params
            params["Authorization"] = APIService.shareManager().weatherKey
            return .requestParameters(parameters: params, encoding: URLEncoding.default)
        }
        
        init(params: [String: Any]) {
            self.params = params
        }
        /// 參數
        private let params: [String: Any]
    }
    
}
