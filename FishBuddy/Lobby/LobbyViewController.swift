//
//  ViewController.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/5.
//

import UIKit
import Combine

class LobbyViewController: UITabBarController {
    // viewModel
    var vm = LobbyVM()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        
    }
    /// 初始化 tabBarController 設定
    private func setup() {
        viewControllers = vm.tabs.map { $0.initVC() }
        tabBar.itemPositioning = .automatic
        tabBar.tintColor = .blue
        delegate = self
    }
    
}

extension LobbyViewController: UITabBarControllerDelegate {
    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController) -> Bool {
        return true
    }
}

