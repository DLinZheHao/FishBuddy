//
//  UIStoryboard+Extension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import UIKit

extension UIStoryboard {
    
    // MARK: 統一管理 storyboard 的創建來源
    static var weatherLobby: UIStoryboard { return stStoryboard(name: "Weather") }
    
    private static func stStoryboard(name: String) -> UIStoryboard {
        return UIStoryboard(name: name, bundle: nil)
    }
    
}
