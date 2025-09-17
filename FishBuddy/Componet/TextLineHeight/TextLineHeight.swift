//
//  TextLineHeight.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/9/17.
//


import SwiftUI


/// 可否設定行高倍數
private var multiple = 0
extension UIFont {
    /// 行高倍數
    var lineHeightMultiple: CGFloat {
        get {
            return objc_getAssociatedObject(self, &multiple) as? CGFloat ?? 0
        }
        set {
            objc_setAssociatedObject(self, &multiple, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension UIFont {
    static func getLineHeight(for font: UIFont) -> CGFloat {
        var lineHeight = font.lineHeight
        if font.lineHeightMultiple > 0 {
            return font.pointSize * font.lineHeightMultiple
        }
        switch font.pointSize {
        case 26:
            lineHeight = 38
        case 34:
            lineHeight = 34
        case 22:
            lineHeight = 32
        case 20:
            lineHeight = 28
        case 19:
            lineHeight = 28
        case 18:
            lineHeight = 26
        case 17:
            lineHeight = 24
        case 16:
            lineHeight = 22
        case 14:
            lineHeight = 20
        case 13:
            lineHeight = 18
        case 12:
            lineHeight = 18
        case 10:
            lineHeight = 12
        case 9:
            lineHeight = 12
        default:
            break
        }
        return lineHeight
    }
}

// 如果有自訂的 getLineHeight(for:)，沿用；否則 fallback 用 font.lineHeight
private func designLineHeight(for font: UIFont) -> CGFloat {
    if let f = UIFont.getLineHeight as ((UIFont) -> CGFloat)? {
        print("Using custom getLineHeight \(f(font))")
        return f(font)
    } else {
        print("Using default lineHeight")
        return font.lineHeight
    }
}

extension String {
    /// 將 String 轉成固定行高 + baseline 微調 + 顏色/字型 的 AttributedString
    func fixedLineHeightAttributedString(
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment? = nil,
        lineBreak: NSLineBreakMode? = nil
    ) -> AttributedString {
        let targetLineHeight = designLineHeight(for: font)
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = targetLineHeight
        para.maximumLineHeight = targetLineHeight
        if let a = alignment { para.alignment = a }
        if let lb = lineBreak { para.lineBreakMode = lb }

        // 與舊邏輯一致的 baseline 微調（如需更保守可改 /6 或 /8）
        let offset = (targetLineHeight - font.lineHeight) / 4

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: para,
            .foregroundColor: color,
            .baselineOffset: offset
        ]
        let ns = NSAttributedString(string: self, attributes: attrs)
        return AttributedString(ns)
    }
}

/// 與 UIKit `textLineHeight` 視覺對齊的 SwiftUI Text 包裝
public struct FixedLineHeightText: View {
    private let attributed: AttributedString
    private let textAlignment: TextAlignment
    private let lineLimitValue: Int?
    private let truncation: Text.TruncationMode
    private let font: UIFont
    /// - Parameters:
    ///   - text: 原始字串
    ///   - font: 使用 UIFont（保留你們原本的字體來源與大小定義）
    ///   - color: 文字顏色（UIColor）
    ///   - alignment: 段落對齊（對應舊的 NSTextAlignment）
    ///   - lineBreak: 斷行/截斷策略（會自動映射為 SwiftUI 的 lineLimit / truncationMode）
    ///   - numberOfLines: 行數上限；預設 nil 表示不限行
    public init(
        _ text: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment? = nil,
        lineBreak: NSLineBreakMode? = nil,
        numberOfLines: Int? = nil
    ) {
        self.font = font
        self.attributed = text.fixedLineHeightAttributedString(
            font: font, color: color, alignment: alignment, lineBreak: lineBreak
        )
        self.textAlignment = Self.mapAlignment(alignment)
        self.lineLimitValue = numberOfLines
        self.truncation = Self.mapTruncation(lineBreak)
    }

    public var body: some View {
        let targetLineHeight = designLineHeight(for: font) // 你已經有算出來了
        Text(attributed)
            .multilineTextAlignment(textAlignment)
            .lineLimit(lineLimitValue)
            .truncationMode(truncation)
            .frame(height: targetLineHeight)
    }

    // MARK: - Mapping helpers

    private static func mapAlignment(_ a: NSTextAlignment?) -> TextAlignment {
        switch a {
        case .some(.center): return .center
        case .some(.right):  return .trailing
        case .some(.justified): return .leading // SwiftUI 沒有 justified，採近似
        default: return .leading
        }
    }

    private static func mapTruncation(_ m: NSLineBreakMode?) -> Text.TruncationMode {
        switch m {
        case .some(.byTruncatingHead):   return .head
        case .some(.byTruncatingMiddle): return .middle
        case .some(.byTruncatingTail):   return .tail
        default: return .tail
        }
    }
}

struct FixedLineHeightModifier: ViewModifier {
    /// 環境字型
    @Environment(\.font) private var envFont
    /// 環境對齊
    @Environment(\.multilineTextAlignment) private var envAlign
    /// 環境行數限制
    @Environment(\.lineLimit) private var envLineLimit
    /// 環境截斷模式
    @Environment(\.truncationMode) private var envTruncation

    /// 設置文字
    let text: String
    /// 設置字型
    let uiFont: UIFont
    /// 設置顏色
    let color: UIColor

    func body(content: Content) -> some View {
        let targetLineHeight = designLineHeight(for: uiFont) // 你已經有算出來了
        // 用你的 getLineHeight + paragraphStyle + baselineOffset 產生 attributed
        let attributed = text.fixedLineHeightAttributedString(
            font: uiFont,
            color: color,
            alignment: map(envAlign),
            lineBreak: map(envTruncation)
        )
        // 直接用我們組好的 Text 取代 content
        Text(attributed)
            .multilineTextAlignment(envAlign)
            .lineLimit(envLineLimit)
            .truncationMode(envTruncation)
            .frame(height: targetLineHeight)
    }

    
    private func map(_ a: TextAlignment) -> NSTextAlignment {
        switch a {
        case .center: return .center
        case .trailing: return .right
        default: return .left
        }
    }
    
    private func map(_ t: Text.TruncationMode) -> NSLineBreakMode {
        switch t {
        case .head: return .byTruncatingHead
        case .middle: return .byTruncatingMiddle
        default: return .byTruncatingTail
        }
    }
}

extension View {
    func fixedLineHeightText(_ text: String, font: UIFont, color: UIColor) -> some View {
        modifier(FixedLineHeightModifier(text: text, uiFont: font, color: color))
    }
}

// MARK: - Preview size debugging helpers
private struct _FBSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private extension View {
    /// Call back with the current measured size of this view.
    func onSizeChange(_ handler: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: _FBSizeKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(_FBSizeKey.self) { size in
            handler(size)
        }
    }

    /// Print size changes to the console in DEBUG builds. Useful in previews.
    func debugPrintSize(_ label: String = "") -> some View {
        onSizeChange { size in
            #if DEBUG
            // Wrap in async to avoid any potential state-change-in-body warnings
            DispatchQueue.main.async {
                if label.isEmpty {
                    print("[Size]", size)
                } else {
                    print("[Size] \(label):", size)
                }
            }
            #endif
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        FixedLineHeightText(
            "台北 → 東京 來回 $12,345",
            font: .systemFont(ofSize: 16, weight: .semibold),
            color: .label,
            alignment: .left,
            lineBreak: .byTruncatingTail,
            numberOfLines: 1
        )
        .background(.blue.opacity(0.6))
        .debugPrintSize("FixedLineHeightText 1")

        FixedLineHeightText(
            "這是一段可能會換行的描述文字，用設計指定的固定行高排版。",
            font: .systemFont(ofSize: 14),
            color: .secondaryLabel,
            alignment: .left,
            lineBreak: .byWordWrapping, // 換行（多行）
            numberOfLines: 3
        )
        .debugPrintSize("FixedLineHeightText 2")
        
        
        Text("") // content 會被替換，不重要
            .font(.subheadline)               // 這些會影響環境，modifier 內可讀取
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .truncationMode(.tail)
            .fixedLineHeightText("台北 → 東京 來回 $12,345",
                                 font: .systemFont(ofSize: 16, weight: .semibold),
                                 color: .label)
            .background(.blue.opacity(0.6))
            .debugPrintSize("FixedLineHeightText 3")
        
    }
    .padding()
    .debugPrintSize("VStack total")
    
}
