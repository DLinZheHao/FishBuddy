//
//  UILabelExtension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/12/12.
//

import UIKit

extension UILabel {
//    /// 設置開頭 icon  + desc (之間有一個空白間隔), 沒有需要 padding 的話不要使用
//    /// - Parameters:
//    ///   - unicode16: 使用的 icon String
//    ///   - desc: 敘述
//    ///   - size: 文字的大小
//    ///   - color: 文字的顏色
//    ///   - iconColor: icon的顏色
//    func setIcon(unicode16: String,
//                 desc: String,
//                 size: CGFloat? = nil,
//                 color: UIColor? = nil,
//                 iconColor: UIColor? = nil,
//                 iconSize: CGFloat = 16,
//                 type: TextBrackets = .green) {
//        
//        let textAttr = NSMutableAttributedString(string: "")
//        /// 設置 icon String 資訊
//        let iconFont = UIFont(name: EzIconFont.fontName, size: iconSize)
//        var iconAtrrs: [NSAttributedString.Key: Any] = [:]
//        iconAtrrs[.font] = iconFont
//        iconAtrrs[.foregroundColor] = iconColor ?? .iOS_gray3()
//        
//        var unicodeStr = ""
//        if let point = Int(unicode16, radix: 16), let scalar = UnicodeScalar(point) {
//            unicodeStr = String(scalar)
//        }
//        let iconStr = NSMutableAttributedString(string: unicodeStr, attributes: iconAtrrs)
//        textAttr.append(iconStr)
//
//        // title
//        let text = " \(desc)"
//        let titleAttrs = NSMutableAttributedString(string: text)
//        var txtColor: UIColor = .iOS_gray1()
//        var txtFont = UIFont.systemFont(ofSize: font.pointSize)
//        
//        if let color = color {
//            txtColor = color
//        } else if let textColor = textColor {
//            txtColor = textColor
//        }
//        
//        if let font = font {
//            txtFont = font
//        } else if let ezFont = UIFont(name: EzIconFont.fontName, size: size ?? font.pointSize)  {
//            txtFont = ezFont
//        }
//        
//        titleAttrs.addAttribute(.foregroundColor, value: txtColor, range: NSMakeRange(0, text.count))
//        titleAttrs.addAttribute(.font, value: txtFont, range: NSMakeRange(0, text.count))
//        titleAttrs.addAttribute(.baselineOffset, value: abs(iconSize - font.lineHeight), range: NSMakeRange(0, text.count))
//        
//        textAttr.append(UILabel.bracketsChageColor(self, titleAttrs, type))
//
//        let paragraphStyle = NSMutableParagraphStyle()
//        paragraphStyle.minimumLineHeight = UIFont.getLineHeight(for: font)
//        paragraphStyle.maximumLineHeight = UIFont.getLineHeight(for: font)
//        paragraphStyle.lineBreakMode = .byTruncatingTail
//        paragraphStyle.alignment = .left
//
//        let range = (textAttr.string as NSString).range(of: textAttr.string)
//        textAttr.addAttributes([.paragraphStyle: paragraphStyle], range: range)
//        
//        attributedText = textAttr
//    }
}
