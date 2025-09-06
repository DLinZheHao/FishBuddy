//
//  UIViewExtension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/5.
//

import Foundation
import UIKit
import Toast

extension UIView {
    /// 顯示自訂吐司訊息
    /// - Parameters:
    ///   - msg:訊息
    @objc public func showToast(_ msg: String?) {
        guard let msg = msg else { return }
        self.showToast(msg, .left)
    }
    
    /// 顯示自訂吐司訊息
    /// - Parameters:
    ///   - msg:訊息
    ///   - msgAlignment:訊息位置，多行使用
    @objc public func showToast(_ msg: String?, _ msgAlignment: NSTextAlignment) {
        guard let msg = msg else { return }
        var style = ToastStyle()
        style.messageColor = UIColor.white
        style.messageFont = UIFont.systemFont(ofSize: 14)
        style.horizontalPadding = 20
        style.verticalPadding = 12
        style.cornerRadius = 6
        style.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        style.messageAlignment = msgAlignment
        makeToast(msg, duration: 2.0, position: .center, style: style)
    }
}
