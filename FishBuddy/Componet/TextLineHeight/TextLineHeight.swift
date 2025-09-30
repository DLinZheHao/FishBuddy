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
    // MARK: 一般細體
    static func iOS_font26() -> UIFont {
        return UIFont.systemFont(ofSize: 26.0)
    }
    static func iOS_font25() -> UIFont {
        return UIFont.systemFont(ofSize: 25.0)
    }
    static func iOS_font22() -> UIFont {
        return UIFont.systemFont(ofSize: 22.0)
    }
    static func iOS_font20() -> UIFont {
        return UIFont.systemFont(ofSize: 20.0)
    }
    static func iOS_font19() -> UIFont {
        return UIFont.systemFont(ofSize: 19.0)
    }
    static func iOS_font18() -> UIFont {
        return UIFont.systemFont(ofSize: 18.0)
    }
    @objc static func iOS_font17() -> UIFont {
        return UIFont.systemFont(ofSize: 17.0)
    }
    static func iOS_font16() -> UIFont {
        return UIFont.systemFont(ofSize: 16.0)
    }
    static func iOS_font14() -> UIFont {
        return UIFont.systemFont(ofSize: 14.0)
    }
    static func iOS_font13() -> UIFont {
        return UIFont.systemFont(ofSize: 13.0)
    }
    @objc static func iOS_font12() -> UIFont {
        return UIFont.systemFont(ofSize: 12.0)
    }
    static func iOS_font10() -> UIFont {
        return UIFont.systemFont(ofSize: 10.0)
    }
    static func iOS_font9() -> UIFont {
        return UIFont.systemFont(ofSize: 9.0)
    }

    // MARK: 中體
    static func iOS_mediumFont13() -> UIFont {
        return UIFont.systemFont(ofSize: 13.0, weight: .medium)
    }
    static func iOS_mediumFont16() -> UIFont {
        return UIFont.systemFont(ofSize: 16.0, weight: .medium)
    }
    
    // MARK: 粗體
    static func iOS_boldFont26() -> UIFont {
        return UIFont.systemFont(ofSize: 26.0, weight: .semibold)
    }
    static func iOS_boldFont25() -> UIFont {
        return UIFont.systemFont(ofSize: 25.0, weight: .semibold)
    }
    static func iOS_boldFont22() -> UIFont {
        return UIFont.systemFont(ofSize: 22.0, weight: .semibold)
    }
    static func iOS_boldFont20() -> UIFont {
        return UIFont.systemFont(ofSize: 20.0, weight: .semibold)
    }
    static func iOS_boldFont19() -> UIFont {
        return UIFont.systemFont(ofSize: 19.0, weight: .semibold)
    }
    static func iOS_boldFont18() -> UIFont {
        return UIFont.systemFont(ofSize: 18.0, weight: .semibold)
    }
    static func iOS_boldFont17() -> UIFont {
        return UIFont.systemFont(ofSize: 17.0, weight: .semibold)
    }
    static func iOS_boldFont16() -> UIFont {
        return UIFont.systemFont(ofSize: 16.0, weight: .semibold)
    }
    static func iOS_boldFont14() -> UIFont {
        return UIFont.systemFont(ofSize: 14.0, weight: .semibold)
    }
    static func iOS_boldFont13() -> UIFont {
        return UIFont.systemFont(ofSize: 13.0, weight: .semibold)
    }
    static func iOS_boldFont12() -> UIFont {
        return UIFont.systemFont(ofSize: 12.0, weight: .semibold)
    }
    static func iOS_boldFont10() -> UIFont {
        return UIFont.systemFont(ofSize: 10.0, weight: .semibold)
    }
    static func iOS_boldFont9() -> UIFont {
        return UIFont.systemFont(ofSize: 9.0, weight: .semibold)
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

// MARK: - Environment bridge for UIFont
private struct _UIFontEnvironmentKey: EnvironmentKey {
    static let defaultValue: UIFont? = nil
}

extension EnvironmentValues {
    var uiFont: UIFont? {
        get { self[_UIFontEnvironmentKey.self] }
        set { self[_UIFontEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// 提供對應的 `UIFont` 到環境，讓僅能拿到 `Font` 的地方也能解析到精確字型
    func uiFont(_ font: UIFont) -> some View {
        environment(\.uiFont, font)
    }
}

struct FixedLineHeightModifier: ViewModifier {
    /// 環境字型
    @Environment(\.uiFont) private var envUIFont
    /// 環境對齊
    @Environment(\.multilineTextAlignment) private var envAlign
    /// 環境行數限制
    @Environment(\.lineLimit) private var envLineLimit
    /// 環境截斷模式
    @Environment(\.truncationMode) private var envTruncation

    /// 設置文字
    let text: String
    /// 設置顏色
    let color: UIColor

    func body(content: Content) -> some View {
        let resolvedUIFont = envUIFont ?? UIFont.iOS_font14()
        let targetLineHeight = designLineHeight(for: resolvedUIFont)
        let attributed = text.fixedLineHeightAttributedString(
            font: resolvedUIFont,
            color: color,
            alignment: map(envAlign),
            lineBreak: map(envTruncation)
        )
        // 直接用我們組好的 Text 取代 content
        let base = Text(attributed)
            .multilineTextAlignment(envAlign)
            .lineLimit(envLineLimit)
            .truncationMode(envTruncation)

        return Group {
            if let limit = envLineLimit {
                base.frame(height: targetLineHeight * CGFloat(limit))
            } else {
                base
            }
        }
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
    func fixedLineHeightText(_ text: String, color: UIColor) -> some View {
        modifier(FixedLineHeightModifier(text: text, color: color))
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
            .fixedLineHeightText("台北 → 東京 來回 $12,345ㄌ 台北 → 東京 來回 $12,345 台北 → 東京 來回 $12,345 台北 → 東京 來回 $12,345 台北 → 東京 來回 $12,345",
                                 color: .label)
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .background(.blue.opacity(0.6))
            .uiFont(.iOS_font16()) // 統一丟進環境
            .debugPrintSize("FixedLineHeightText main")
        
    }
    .padding()
    .debugPrintSize("VStack total")
    
}
