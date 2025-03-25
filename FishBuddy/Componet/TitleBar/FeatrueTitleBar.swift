//
//  FeatrueTitleBar.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import UIKit

/// VacationSubViews  index
//enum VacationSubViewXibIndex: Int {
//    /// 價格詳情頁 --- 房型的價格資訊
//    case roomPrice = 0
//}

// MARK: viewController 使用的 titleBar (取代原生的)
class FeatrueTitleBar: UIView {
    
    /// 初始化物件
    class func fromXib() -> FeatrueTitleBar {
        let nib = UINib(nibName: "FeatrueTitleBar", bundle: nil)
        let view = nib.instantiate(withOwner: nil, options: nil).first as! FeatrueTitleBar
        return view
    }

}
