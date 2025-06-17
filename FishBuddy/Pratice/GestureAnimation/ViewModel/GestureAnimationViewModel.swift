//
//  GestureAnimationViewModel.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/6.
//

import Foundation

enum DragState {
    case inactive
    case pressing
    case dragging(translation: CGSize)
    
    /// 更新拖曳狀態 -> 使用者手勢移動物件的位置數值
    var translation: CGSize {
        switch self {
        case .inactive, .pressing:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
    
    /// 是否正在拖曳或按壓
    var isDragging: Bool {
        switch self {
        case .dragging:
            return true
        case .pressing, .inactive:
            return false
        }
    }
    
    /// 是否正在按壓
    var isPressing: Bool {
        switch self {
        case .pressing, .dragging:
            return true
        case .inactive:
            return false
        }
    }
    
}
