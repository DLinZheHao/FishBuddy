//
//  APIService.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/5.
//

import Foundation
import Moya
import Combine

class APIService {
    /// 唯一運行
    private static let instance = APIService()
    /// 預設Request的資料格式
    public static let defaultRequestType: APIMediaType = .json
    /// 預設Response的資料格式
    public static let defaultResponseType: APIMediaType = .json
    /// 預設API Timeout時間為60
    public static let defaultTimeout: Double = 20.0
    /// 預設的cache類別
    public static let defaultCacheType: URLRequest.CachePolicy = .useProtocolCachePolicy
    /// taskPool 操作 queue
    private var taskPoolQueue =  DispatchQueue(label: "APIService.taskPool", attributes: .concurrent)
    /// 記錄目前的 request 池
    private var taskPool = [String: Moya.Cancellable]()
    
    // MARK: 可更改
    /// Reqeust的資料格式
    public var requestType: APIMediaType = APIService.defaultRequestType
    /// Response的資料格式
    public var responseType: APIMediaType = APIService.defaultResponseType
    /// API 請求超時時間
    public var timeout: Double = APIService.defaultTimeout
    /// 暫存類別
    public var cacheType: URLRequest.CachePolicy = APIService.defaultCacheType
    
    // MARK: 授權碼
    /// 氣象局網站授權碼
    var weatherKey = "CWA-BFB6A0E3-0705-4F0C-A8E5-5524B97BB466"
    
    // MARK:- API Endpoint 網路請求設定
    /// endpointClosure (HTTP Header)
    private let endpointClosure = { (target: MultiTarget) -> Endpoint in
        var endpoint = MoyaProvider.defaultEndpointMapping(for: target)
        
        // accept (req)
        let accept = instance.requestType.rawString()
        endpoint = endpoint.adding(newHTTPHeaderFields: ["Accept": accept])
        
        // content-type (res)
        let contentType = instance.responseType.rawString()
        endpoint = endpoint.adding(newHTTPHeaderFields: ["Content-type": contentType])
        
        // target 額外設的 headers
        if let header = target.headers, !header.isEmpty {
            header.forEach { endpoint = endpoint.adding(newHTTPHeaderFields: [$0: $1]) }
        }
        
        return endpoint
    }
    
    // MARK:- API Request 網路請求設定
    /// requestClosure
    private let requestClosure = { (endpoint: Endpoint, done: MoyaProvider.RequestResultClosure) in
        do {
            var request = try endpoint.urlRequest()
            request.timeoutInterval = instance.timeout
            request.cachePolicy = instance.cacheType
            done(.success(request))
        } catch {
            done(.failure(MoyaError.underlying(error, nil)))
        }
    }

    /// 外部使用唯一運行辦法 （預設）
    public static func shareManager() -> APIService {
        // TODO: 可以在這裡新增屬性
        return instance
    }
    
    /// 取消請求
    /// - Parameter target: 要取消的 target
    public func cancelRequest(target: TargetType) {
        self.taskPoolQueue.async(flags: .barrier) {
            self.taskPool[target.path]?.cancel()
            self.taskPool.removeValue(forKey: target.path)
        }
    }
    
    /// 使用 combine + Moya 進行 API 資料請求
    func requestDataCombine(target: TargetType) -> AnyPublisher<Any?, MoyaError> {
        let target = MultiTarget(target)
        let provider = MoyaProvider<MultiTarget>(endpointClosure: endpointClosure,
                                                 requestClosure: requestClosure)
        
        let result = Future<Any?, MoyaError> { promise in
            let cancellable = provider.request(target) { result in
                switch result {
                case .success(let response):
                    do {
                        let data = try response.filter(statusCode: 200).data
                        promise(.success(data))
                    } catch let error {
                        if let error = error as? MoyaError {
                            promise(.failure(error))
                        } else {
                            promise(.failure(MoyaError.jsonMapping(response)))
                        }
                    }
                case .failure(let error):
                    promise(.failure(error))
                }
                self.taskPoolQueue.async(flags: .barrier) {
                    // 成功失敗都移除（表示已經完成這 request）
                    self.taskPool.removeValue(forKey: target.path)
                }
            }
            
            self.taskPoolQueue.async(flags: .barrier) {
                // 將 cancellable 加入 taskPool
                self.taskPool[target.path] = cancellable
            }
        }
        .eraseToAnyPublisher()
        
        return result
    }
}


