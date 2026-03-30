//
//  AppDelegate.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/5.
//

import UIKit
import FoundationModels

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task {
            await EmbeddingStore.shared.prepare()
            do {
                try await UserStore.shared.prepare()
            }
            catch {
                print("資料庫讀取發生錯誤！ \(error)")
            }
            if #available(iOS 26.0, *) {
                let model = SystemLanguageModel.default
                
                // The availability property provides detailed information on the model's state.
                switch model.availability {
                case .available:
                    print("Foundation Models is available and ready to go!")
                    
                case .unavailable(.deviceNotEligible):
                    print("The model is not available on this device.")
                    
                case .unavailable(.appleIntelligenceNotEnabled):
                    print("Apple Intelligence is not enabled in Settings.")
                    
                case .unavailable(.modelNotReady):
                    print("The model is not ready yet. Please try again later.")
                    
                case .unavailable(_):
                    print("The model is unavailable for an unknown reason.")
                }
            }
        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

