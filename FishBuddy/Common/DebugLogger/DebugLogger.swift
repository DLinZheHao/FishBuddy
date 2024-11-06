//
//  DebugLogger.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/6.
//

import Foundation
import OSLog
import Moya

class DebugLogger: NSObject {
    
    /// 結果的類別
    enum ResultLoggerType {
        /*
        訊息持久性(message persistence)由小到大，Performace由快到慢
         - debug: 只有當下可以看，最快
         - info: 用指令可以collect log
         - notice (default): 存起來直到儲存已滿
         - error: 存起來直到儲存已滿
         - fault: 存起來直到儲存已滿，最慢
        */
        case debug
        case info
        case notice
        case error
        case fault
    }
    
    /// 功能標籤
    enum FeatureType: String, CaseIterable {
        case debug
        case api
        case pkg
    }
    
    /// Singleton
    @objc static let shared = DebugLogger()

    /// 使用 log 來貼出結果訊息 (ios 14 以上 log，以下 print )
    /// - Parameters:
    ///   - type: log 的類型，預設 info
    ///   - subsystem: 功能，預設 debug
    ///   - category: 功能底下的分類（自行輸入）
    ///   - content: 打印的內容
    func useLog(_ type: ResultLoggerType = .info,
                _ subsystem: FeatureType = .debug,
                _ category: String = "",
                content: Any) {
        if #available(iOS 14.0, *) {
            let message = "\(content)"
            let logger = Logger(subsystem: subsystem.rawValue, category: category)
            switch type {
            case .debug:
                logger.debug("\(message)")
            case .error:
                logger.error("\(message)")
            case .fault:
                logger.fault("\(message)")
            case .info:
                logger.info("\(message)")
            case .notice:
                logger.notice("\(message)")
            }
        } else {
            print("[DEBUG][\(subsystem)][\(category)] \(content)")
        }
    }
}
