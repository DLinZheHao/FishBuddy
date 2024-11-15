//
//  UIViewControllerExtension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import Foundation
import UIKit

extension UIViewController {
    
    /// 直接取用 object 名稱作為識別
    static var identifier: String {
        return String(describing: self)
    }
    
}
