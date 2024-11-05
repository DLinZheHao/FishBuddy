//
//  PublisherExtension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/5.
//

import UIKit
import Combine

// 讓 assign 是 weak self，避免咬住
extension Publisher where Failure == Never {
    
    /// 與 .assign(to: on:) 同功能（只差在一個是弱引用，一個是強引用）
    func weakAssign<T: AnyObject>(
            to keyPath: ReferenceWritableKeyPath<T, Output>,
            on object: T?
        ) -> AnyCancellable {
            sink { [weak object] value in
                // 只有當 object 不為 nil 時才賦予值
                object?[keyPath: keyPath] = value
            }
        }
}

extension Publisher where Failure: Error {
    
    /// = .sink(receiveValue: )
    func weakSink<T: AnyObject>(with context: T, onNext: @escaping (T, Output) -> Void) -> AnyCancellable {
        return self
            .catch { _ in Empty<Output, Never>() }
            .sink { [weak context] output in
                guard let context = context else { return }
                onNext(context, output)
            }
    }
    
    /// 過濾訊號 = drop(while:)
    func dropWeakSink<T: AnyObject>(with context: T, shouldDrop: @escaping (T, Output) -> Bool) -> AnyPublisher<Output, Failure> {
        return self
            .drop(while: { [weak context] output in
                guard let context = context else { return false }
                return shouldDrop(context, output)
            })
            .flatMap { Just($0).setFailureType(to: Failure.self) }
            .eraseToAnyPublisher()
    }
}

extension Publisher where Output == String, Failure == Never {
    /// Combine UILabel textLineHeight
    /// - Parameter label:
    /// - Returns:
//    func textLineHeight(to label: UILabel?) -> AnyCancellable {
//        self.sink { [weak label] text in
//            label?.textLineHeight(text)
//        }
//    }
}

extension Publisher where Output == (String, UIEdgeInsets), Failure == Never {
    
//    /// Combine UILabel textLineHeight + Padding
//    /// - Parameter label: UILabelPadding
//    /// - Returns:
//    func textLineHeightAndInset(to label: UILabelPadding?) -> AnyCancellable {
//        self.sink { [weak label] text, insets in
//            label?.paddingTop = insets.top
//            label?.paddingBottom = insets.bottom
//            label?.paddingLeft = insets.left
//            label?.paddingRight = insets.right
//            label?.textLineHeight(text)
//        }
//    }
}


// MARK: - Combine String 擴充
extension Publisher where Output == String {
    /// 過濾非數字
    func decimalDigits() -> Publishers.Map<Self, String> {
        return self.map { $0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined() }
    }
    
    /// 過濾空白
    func trimWhitespaces() -> Publishers.Map<Self, String> {
        return self.map { $0.components(separatedBy: .whitespaces).joined() }
    }
    
    /// 限制字數長度
    /// - Parameter word: 字數
    func prefix(_ word: Int) -> Publishers.Map<Self, String> {
        return self.map { String($0.prefix(word)) }
    }
    
    /// 過濾非正規化條件以外的字
    /// - Parameter regex: 正規化規則
    /// - Returns: 濾掉後的字
//    func regexFilter(_ regex: String) -> Publishers.Map<Self, String> {
//        return self.map { $0.matches(for: regex) }
//    }
    
    /// 數字欄位格式化遮罩
    /// - Parameters:
    ///   - mask: 遮罩格式 ex:"## - ####"
    ///   - replace: 遮罩字元 "#"
    /// - Returns: "08 - 2021"
//    func numberFormat(_ mask: String,_ replace: Character) -> Publishers.Map<Self, String> {
//        return self.map { $0.numberFormat(mask, replace) }
//    }
}
