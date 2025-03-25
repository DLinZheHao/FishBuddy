//
//  TagLineView.swift
//  MapleStoryManager
//
//  Created by LinZheHao on 2024/6/12.
//

import UIKit

enum TagLineViewsIndex: Int {
    /// 主容器
    case container = 0
    /// tag
    case tag
}


struct TagLineAttribute {
    // Text
    /// 標籤文字
    var desc: String
    /// 標籤文字行數
    var line: Int = 0
    /// 標籤文字大小
    var fontSize: CGFloat = 17
    /// 文字顏色
    var textColor: UIColor = .gray
    /// 文字對齊
    var txtAlignment: NSTextAlignment = .left
    
    // Padding
    /// 文字左邊 padding
    var paddingLeft = 4
    /// 文字右邊 padding
    var paddingRight = 4
    /// 文字上面 padding
    var paddingTop = 1
    /// 文字下面 padding
    var paddingBottom = 1
    
    // Border
    /// border 邊寬
    var borderWid: CGFloat = 1
    /// border 顏色
    var borderColor: CGColor = UIColor.gray.cgColor
    /// border 圓角
    var cornerRadius: CGFloat = 2
    
    // Icon
    /// icon 文字
    var icon: String = ""
    /// icon 大小
    var iconSize: CGFloat = 16
    /// 是否要啟用 icon + desc (暫時不開放)
    var isAddHeadIcon: Bool = false
    
    // Background
    var backgroundColor: UIColor = .white
}

class TagLineView: UIView {
    /// 裝 tags 的容器
    @IBOutlet weak var bgStackView: UIStackView!
    /// 行之間的距離
    let lineSpace: CGFloat = 1
    /// tag 之間的距離
    var itemSpace: CGFloat = 8
        
    /// 創建物件使用
    class func fromXib(maxWidth: CGFloat, tagStrs: [String]) -> TagLineView {
        let nib = UINib(nibName: "TagLineView", bundle: nil)
        let index = TagLineViewsIndex.container.rawValue
        let view = nib.instantiate(withOwner: nil, options: nil)[index] as! TagLineView
        return view
    }
    
    func setup(maxWid: CGFloat, lineSpace: CGFloat, tags: [TagLineAttribute]) {
        if tags.isEmpty { return }
        bgStackView.spacing = lineSpace
        bgStackView.subviews.forEach { $0.removeFromSuperview() }
        
        // 儲存使用的 section (View) item (Label)
        var bgViews = [UIView]()
        var tagLabels = [UILabel]()
        
        // 管理儲存的 section (View) item (Label) 怎麼使用
        var widCount: CGFloat = 0
        var bgViewIndex = 0
        var tagIndex = 0
        
        for (index, tag) in tags.enumerated() {
            // 創建 tag
            let tagLabel = paddingLabelSet(tag)
            
            // 計算 label 在特定高度限制下的尺寸
            let maxSize = CGSize(width: maxWid, height: tagLabel.font.lineHeight)
            let requiredSize = tagLabel.sizeThatFits(maxSize)
            
            // itemSpace -> item 之間 spacing，超過可用就要產一個新的 bgView (換行)
            if widCount + requiredSize.width + itemSpace >= maxWid {
                // 換行就要清空
                tagLabels = []
                widCount = 0
                tagIndex = 0
                
                // 新建一行
                addSection(&bgViews)
                // 避免初始化第一行就佔據全部空間的情況，這種情況 bgViewIndex 不需要加 1
                if index != 0 {
                    bgViewIndex += 1
                }
                
                bgViews[bgViewIndex].addSubview(tagLabel)
                setAllConstraint(tagLabel, bgViews[bgViewIndex], requiredSize.height, widCount >= maxWid)
                
                // 新的 tag 會佔據整行的話，就需要再建立新的一行
                if widCount >= maxWid {
                    addSection(&bgViews)
                    bgViewIndex += 1
                // 同一行繼續使用
                } else {
                    widCount += requiredSize.width + itemSpace
                    tagIndex += 1
                    tagLabels.append(tagLabel)
                }
            } else {
                if bgViews.isEmpty { addSection(&bgViews) }
                bgViews[bgViewIndex].addSubview(tagLabel)
                setViewHConstraint(bgViews[bgViewIndex], requiredSize.height)
                
                tagLabel.translatesAutoresizingMaskIntoConstraints = false
                
                if tagLabels.isEmpty {
                    setTagConstraint(tagLabel, bgViews[bgViewIndex], isTag: false)
                } else {
                    setTagConstraint(tagLabel, bgViews[bgViewIndex], tagLabels[tagIndex - 1], isTag: true)
                }
                
                tagLabels.append(tagLabel)
                tagIndex += 1
                widCount += requiredSize.width + itemSpace
            }
        }
    }
    
    /// 新增新的一列
    private func addSection(_ bgViews: inout [UIView]) {
        let bgView = UIView()
        bgStackView.addArrangedSubview(bgView)
        bgViews.append(bgView)
    }

    /// 設置 tag label 屬性
    private func paddingLabelSet(_ attribute: TagLineAttribute) -> UILabelPadding {
        let tagLabel = UILabelPadding()
        tagLabel.numberOfLines = attribute.line
        tagLabel.font = UIFont.systemFont(ofSize: attribute.fontSize)
        tagLabel.textColor = attribute.textColor
        if attribute.isAddHeadIcon {
//            tagLabel.setIcon(unicode16: attribute.icon, desc: attribute.desc, iconColor: attribute.iconColor,
//                             iconSize: attribute.iconSize, type: .orange)
        } else {
//            tagLabel.textLineHeight(attribute.desc)
        }
        
        tagLabel.layer.borderWidth = attribute.borderWid
        tagLabel.layer.borderColor = attribute.borderColor
        tagLabel.layer.cornerRadius = attribute.cornerRadius
        tagLabel.textAlignment = attribute.txtAlignment
        tagLabel.paddingLeft = CGFloat(attribute.paddingLeft)
        tagLabel.paddingRight = CGFloat(attribute.paddingRight)
        tagLabel.paddingTop = CGFloat(attribute.paddingTop)
        tagLabel.paddingBottom = CGFloat(attribute.paddingBottom)
        tagLabel.backgroundColor = attribute.backgroundColor
        return tagLabel
    }
    
    private func setViewHConstraint(_ view: UIView, _ height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: height)
        heightConstraint.priority = UILayoutPriority(1000)
        heightConstraint.isActive = true
    }
    
    private func setAllConstraint(_ label: UILabel, _ view: UIView, _ height: CGFloat, _ isEntire: Bool) {
        setViewHConstraint(view, height)
        label.translatesAutoresizingMaskIntoConstraints = false
        // 佔據整列
        if isEntire {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: view.topAnchor),
                label.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        // 非佔據整列
        } else {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: view.topAnchor),
                label.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            ])
        }
    }
    
    private func setTagConstraint(_ label: UILabel, _ view: UIView, _ label2: UILabel? = nil, isTag: Bool) {
        label.translatesAutoresizingMaskIntoConstraints = false
        // 如果已經有 tag 存在列中
        if isTag, let label2 = label2 {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: view.topAnchor),
                label.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
                label.leadingAnchor.constraint(equalTo: label2.trailingAnchor, constant: itemSpace)
            ])
        // 沒有 tag 存在列中
        } else {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: view.topAnchor),
                label.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            ])
        }
    }
    
}


