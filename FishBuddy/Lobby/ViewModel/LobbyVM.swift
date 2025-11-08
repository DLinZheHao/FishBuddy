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
                controller.tabBarItem = makeTabBarItem(title: "天氣",
                                                       imageSystemName: "cloud.sun",
                                                       selectedSystemName: "cloud.sun.fill")
                
            case .imageRecognition:
                controller = CameraStreamVC()
                controller.tabBarItem = makeTabBarItem(title: "辨識",
                                                       imageSystemName: "camera",
                                                       selectedSystemName: "camera.fill")
            }
            return controller
        }
        
        /// 製作 tab 物件
        private func makeTabBarItem(title: String,
                                    imageSystemName: String,
                                    selectedSystemName: String? = nil) -> UITabBarItem {
            let image = UIImage(systemName: imageSystemName)
            let selectedImage = selectedSystemName.flatMap { UIImage(systemName: $0) }
            let item = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
            return item
        }
    }
    
}

// MARK: - Hosting Controllers
class CameraStreamVC: UIHostingController<CameraStreamView> {
    
    init() {
        let view = CameraStreamView()
        super.init(rootView: view)
        
        // 讓 SwiftUI 的 onClose 真的切 tab
        self.rootView = CameraStreamView(onClose: { [weak self] in
            self?.tabBarController?.selectedIndex = 0   // 切回天氣 tab
        })
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: CameraStreamView())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
        self.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
