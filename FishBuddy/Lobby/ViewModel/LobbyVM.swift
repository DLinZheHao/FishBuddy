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
    var tabs: [Tab] = [.userLobby, .weather, .imageRecognition, .collection]
    
}

// MARK: 擴充結構
extension LobbyVM {
    /// 功能列
    enum Tab {
        // 天氣狀態
        case weather
        // 圖片辨識
        case imageRecognition
        // 使用者首頁
        case userLobby
        // 收藏頁
        case collection
        
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
                
            case .userLobby:
                controller = UserLobbyVC()
                controller.tabBarItem = makeTabBarItem(title: "首頁",
                                                       imageSystemName: "house",
                                                       selectedSystemName: "house.fill")

            case .collection:
                controller = CollectionVC()
                controller.tabBarItem = makeTabBarItem(title: "收藏",
                                                       imageSystemName: "square.grid.2x2",
                                                       selectedSystemName: "square.grid.2x2.fill")
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
        // init 之前不能使用 self 所以會初始化兩次
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

class UserLobbyVC: UIHostingController<UserHomeView> {
    
    init() {
        super.init(rootView: UserHomeView())
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: UserHomeView())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        tabBarController?.tabBar.isHidden = false
        self.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        tabBarController?.tabBar.isHidden = false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

class CollectionVC: UIHostingController<CollectionView> {

    init() {
        super.init(rootView: CollectionView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: CollectionView())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
