//
//  APIStatus.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/5.
//

import Foundation
import Moya

/// API 網路狀態
enum APIStatus {
   /// 網路穩定且有資料
   case success
   /// 網路穩定但沒資料
   case noData
   /// 網路不穩或伺服器壞掉
   case failure
}

/// API 錯誤類別
enum APIFailType {
    /// 4xx 用戶端錯誤（Client Error）
    case clientError
    /// 5xx 伺服器錯誤（Server Error）
    case serverError
    /// 取消
    case cancel
    
    /// 回覆 API 錯誤類別
    /// - Parameter errorCode: http error code
    init(error: MoyaError) {
        switch error {
        case .statusCode(let response):
            switch response.statusCode {
            case 400..<500:
                self = .clientError
            default:
                self = .serverError
            }
        default:
            self = .serverError
        }
    }
}

/// API 呼叫媒體類別
public enum APIMediaType: Int {
    /// application/json
    case json
    /// application/x-www-form-urlencoded
    case http
    /// image/gif
    case gif
    /// javascript
    case javascript
    /// */*
    case any
    
    /// rawValue String
    func rawString() -> String {
        switch self {
        case .json:
            return "application/json"
        case .http:
            return "application/x-www-form-urlencoded"
        case .gif:
            return "image/gif"
        case .javascript:
            return "text/javascript; charset=utf-8"
        case .any:
            return "*/*"
        }
    }
}

class APIBaseURLConfig {
    /// 本地 domain
    static var domainAPI = "http://192.168.0.224:3000"
    
    /// 氣象署天氣服務
    static var weatherBaseURL: URL {
        return URL(string: domainAPI + "/forecast")!
    }
}
