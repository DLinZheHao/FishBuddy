//
//  LobbyVM.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import Foundation
import UIKit
import Combine
import SwiftUI

class LobbyVM {
    // 綁訂事件
    var cancellables = Set<AnyCancellable>()
    
    // tabs 資料
    var tabs: [Tab] = [.weather, .imageRecognition]
    
}

// MARK: 擴充結構
extension LobbyVM {
    /// 功能列
    enum Tab {
        // 天氣狀態首頁
        case weather
        // 潮汐資料狀態首頁
        
        // 圖片辨識
        case imageRecognition
        
        /// 創建 tab 使用的 vc
        func initVC() -> UIViewController {
            let controller: UIViewController
            switch self {
            // 天氣
            case .weather:
                let storyboard = UIStoryboard.weatherLobby
                controller = storyboard.instantiateViewController(withIdentifier: WeatherLobbyViewController.identifier)
                controller.tabBarItem = makeTabBarItem("天氣")
            // 潮汐
//                
//                let swiftUIView = WeatherView(vm: vm)
//                let hostingController = UIHostingController(rootView: swiftUIView)
                
            
            case .imageRecognition:
                controller = CameraStreamVC(rootView: CameraStreamView())
                controller.tabBarItem = makeTabBarItem("辨識")
            }
            return controller
        }
        
        /// 製作 tab 物件
        private func makeTabBarItem(_ title: String) -> UITabBarItem {
            return UITabBarItem(title: title, image: nil, selectedImage: nil)
        }
        
//        private var image: UIImage? {
//            switch self {
//            case .ingredients:
//                return UIImage(systemName: "refrigerator")
//            case .teamLink:
//                return UIImage(systemName: "person.2.crop.square.stack")
//            case .join:
//                return UIImage(systemName: "person.crop.circle.badge.plus")
//            case .calendarPage:
//                return UIImage(systemName: "calendar.circle")
//            case .measure:
//                return UIImage(systemName: "ruler")
//            }
//        }
//
//        private var selectedImage: UIImage? {
//            switch self {
//            case .ingredients:
//                return UIImage(systemName: "refrigerator.fill")?.withRenderingMode(.alwaysOriginal)
//            case .teamLink:
//                return UIImage(systemName: "person.2.crop.square.stack.fill")?.withRenderingMode(.alwaysOriginal)
//            case .join:
//                return UIImage(systemName: "person.crop.circle.fill.badge.plus")?.withRenderingMode(.alwaysOriginal)
//            case .calendarPage:
//                return UIImage(systemName: "calendar.circle.fill")
//            case .measure:
//                return UIImage(systemName: "ruler.fill")?.withRenderingMode(.alwaysOriginal)
//            }
//        }
        
    }
    
}

// MARK: - Hosting Controllers
class CameraStreamVC: UIHostingController<CameraStreamView> {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
