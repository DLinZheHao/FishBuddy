//
//  FontExtension.swift
//  EzApp
//
//  Created by LinZheHao on 2025/9/22.
//  Copyright © 2025 tw.com.eztravel. All rights reserved.
//

import SwiftUI


// MARK: - Environment bridge for UIFont
private struct UIFontEnvironmentKey: EnvironmentKey {
    static let defaultValue: UIFont? = nil
}

extension EnvironmentValues {
    var uiFont: UIFont? {
        get { self[UIFontEnvironmentKey.self] }
        set { self[UIFontEnvironmentKey.self] = newValue }
    }
}

extension Font {
    // MARK: 一般細體
    static func iOS_font26() -> Font {
        return Font(UIFont.systemFont(ofSize: 26.0))
    }
    static func iOS_font25() -> Font {
        return Font(UIFont.systemFont(ofSize: 25.0))
    }
    static func iOS_font22() -> Font {
        return Font(UIFont.systemFont(ofSize: 22.0))
    }
    static func iOS_font20() -> Font {
        return Font(UIFont.systemFont(ofSize: 20.0))
    }
    static func iOS_font19() -> Font {
        return Font(UIFont.systemFont(ofSize: 19.0))
    }
    static func iOS_font18() -> Font {
        return Font(UIFont.systemFont(ofSize: 18.0))
    }
    static func iOS_font17() -> Font {
        return Font(UIFont.systemFont(ofSize: 17.0))
    }
    static func iOS_font16() -> Font {
        return Font(UIFont.systemFont(ofSize: 16.0))
    }
    static func iOS_font14() -> Font {
        return Font(UIFont.systemFont(ofSize: 14.0))
    }
    static func iOS_font13() -> Font {
        return Font(UIFont.systemFont(ofSize: 13.0))
    }
    static func iOS_font12() -> Font {
        return Font(UIFont.systemFont(ofSize: 12.0))
    }
    static func iOS_font10() -> Font {
        return Font(UIFont.systemFont(ofSize: 10.0))
    }
    static func iOS_font9() -> Font {
        return Font(UIFont.systemFont(ofSize: 9.0))
    }

    // MARK: 中體
    static func iOS_mediumFont13() -> Font {
        return Font(UIFont.systemFont(ofSize: 13.0, weight: .medium))
    }
    static func iOS_mediumFont16() -> Font {
        return Font(UIFont.systemFont(ofSize: 16.0, weight: .medium))
    }
    
    // MARK: 粗體
    static func iOS_boldFont26() -> Font {
        return Font(UIFont.systemFont(ofSize: 26.0, weight: .semibold))
    }
    static func iOS_boldFont25() -> Font {
        return Font(UIFont.systemFont(ofSize: 25.0, weight: .semibold))
    }
    static func iOS_boldFont22() -> Font {
        return Font(UIFont.systemFont(ofSize: 22.0, weight: .semibold))
    }
    static func iOS_boldFont20() -> Font {
        return Font(UIFont.systemFont(ofSize: 20.0, weight: .semibold))
    }
    static func iOS_boldFont19() -> Font {
        return Font(UIFont.systemFont(ofSize: 19.0, weight: .semibold))
    }
    static func iOS_boldFont18() -> Font {
        return Font(UIFont.systemFont(ofSize: 18.0, weight: .semibold))
    }
    static func iOS_boldFont17() -> Font {
        return Font(UIFont.systemFont(ofSize: 17.0, weight: .semibold))
    }
    static func iOS_boldFont16() -> Font {
        return Font(UIFont.systemFont(ofSize: 16.0, weight: .semibold))
    }
    static func iOS_boldFont14() -> Font {
        return Font(UIFont.systemFont(ofSize: 14.0, weight: .semibold))
    }
    static func iOS_boldFont13() -> Font {
        return Font(UIFont.systemFont(ofSize: 13.0, weight: .semibold))
    }
    static func iOS_boldFont12() -> Font {
        return Font(UIFont.systemFont(ofSize: 12.0, weight: .semibold))
    }
    static func iOS_boldFont10() -> Font {
        return Font(UIFont.systemFont(ofSize: 10.0, weight: .semibold))
    }
    static func iOS_boldFont9() -> Font {
        return Font(UIFont.systemFont(ofSize: 9.0, weight: .semibold))
    }
}
