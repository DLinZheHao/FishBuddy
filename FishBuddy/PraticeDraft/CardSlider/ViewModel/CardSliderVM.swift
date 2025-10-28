//
//  CardSliderVM.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/17.
//

import SwiftUI


enum CardDragState {
    /// 狀態：無操作
    case inactive
    /// 狀態：按壓中
    case pressing(index: Int? = nil)
    /// 狀態：拖曳中
    case dragging(index: Int? = nil, translation: CGSize)
    
    /// 按壓點擊的索引
    var index: Int? {
        switch self {
        case .pressing(let index), .dragging(let index, _):
            return index
        case .inactive:
            return nil
        }
    }
    /// 拖曳的位移
    var translation: CGSize {
        switch self {
        case .inactive, .pressing:
            return .zero
        case .dragging(_, let translation):
            return translation
        }
    }
    /// 是否正在按壓或拖曳
    var isPressing: Bool {
        switch self {
        case .pressing, .dragging:
            return true
        case .inactive:
            return false
        }
    }
    /// 是否正在拖曳
    var isDragging: Bool {
        switch self {
        case .dragging:
            return true
        case .inactive, .pressing:
            return false
        }
    }
}
