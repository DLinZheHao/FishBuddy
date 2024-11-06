//
//  APILoggerPlugin.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/6.
//

import Foundation
import Moya

class APILoggerPlugin: PluginType {
    
    private let configuration: NetworkLoggerPlugin.Configuration
    
    init(configuration: NetworkLoggerPlugin.Configuration) {
        self.configuration = configuration
    }
    
    /// 當請求將要傳送時，呼叫 logNetworkRequest 方法來記錄請求的訊息
    func willSend(_ request: RequestType, target: TargetType) {
        logNetworkRequest(request, target: target) { logs in
            for log in logs {
                DebugLogger.shared.useLog(.info, .api, content: log)
            }
        }
    }
    
    /// 在接收到回應後，根據回應的結果（成功或失敗），分別呼叫logNetworkResponse或logNetworkError方法
    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        let logs: [String]
        switch result {
        case .success(let response):
            logs = logNetworkResponse(response, target: target, isFromError: false)
        case .failure(let error):
            logs = logNetworkError(error, target: target)
        }
        for log in logs {
            DebugLogger.shared.useLog(.info, .api, content: log)
        }
    }
    
    /// 記錄請求的詳細訊息，包括cURL 格式的請求、HTTP 方法等，並透過回呼函數將日誌內容傳遞回去。
    private func logNetworkRequest(_ request: RequestType, target: TargetType, completion: @escaping ([String]) -> Void) {
        var output = [String]()
        
        // cURL formatting
        if configuration.logOptions.contains(.formatRequestAscURL) {
            _ = request.cURLDescription { outputString in
                output.append(self.configuration.formatter.entry("Request", outputString, target))
                completion(output)
            }
            return
        }
        
        // Request presence check
        guard let httpRequest = request.request else {
            output.append(configuration.formatter.entry("Request", "(invalid request)", target))
            completion(output)
            return
        }
        
        // Adding log entries for each given log option
        output.append(configuration.formatter.entry("Request", httpRequest.description, target))
        
        if configuration.logOptions.contains(.requestMethod),
           let httpMethod = httpRequest.httpMethod {
            output.append(configuration.formatter.entry("HTTP Request Method", httpMethod, target))
        }
        
        // Logging request headers
        if configuration.logOptions.contains(.requestHeaders) {
            var allHeaders = request.sessionHeaders
            if let httpRequestHeaders = httpRequest.allHTTPHeaderFields {
                allHeaders.merge(httpRequestHeaders) { $1 }
            }
            output.append(configuration.formatter.entry("Request Headers", allHeaders.description, target))
        }
        
        if let httpBody = httpRequest.httpBody,
           let bodyString = String(data: httpBody, encoding: .utf8) {
            output.append(configuration.formatter.entry("Request Body", bodyString, target))
        } else {
            output.append(configuration.formatter.entry("Request Body", "[Empty or unable to format body]", target))
        }
        
        completion(output)
    }
    
    /// 記錄回應的詳細訊息，回傳值如果是JSON 格式，則格式化為易讀的字串。
    private func logNetworkResponse(_ response: Response, target: TargetType, isFromError: Bool) -> [String] {
        var output = [String]()
        
        if (isFromError && configuration.logOptions.contains(.errorResponseBody))
            || configuration.logOptions.contains(.successResponseBody) {
            
            let stringOutput = configuration.formatter.responseData(response.data)
            output.append(configuration.formatter.entry("Response Body", stringOutput, target))
        }
        
        return output
    }
    
    /// 記錄錯誤訊息，如果錯誤包含回應，則呼叫 logNetworkResponse 以記錄該回應。
    private func logNetworkError(_ error: MoyaError, target: TargetType) -> [String] {
        if let moyaResponse = error.response {
            return logNetworkResponse(moyaResponse, target: target, isFromError: true)
        }
        
        return [configuration.formatter.entry("Error", "Error calling \(target): \(error.localizedDescription)", target)]
    }
}

