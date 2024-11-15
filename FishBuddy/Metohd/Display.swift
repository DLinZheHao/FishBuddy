//
//  Display.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import Foundation
import UIKit

class AppDisplay {
    // 共用實例
    static var sharded = AppDisplay()
    
    func fontScale(for category: UIContentSizeCategory) -> CGFloat {
        switch category {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.5
        case .accessibilityLarge: return 1.6
        case .accessibilityExtraLarge: return 1.7
        case .accessibilityExtraExtraLarge: return 1.8
        case .accessibilityExtraExtraExtraLarge: return 1.9
        default: return 1.0
        }
    }
}
