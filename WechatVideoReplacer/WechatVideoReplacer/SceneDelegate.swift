//
//  SceneDelegate.swift
//  WechatVideoReplacer
//
//  Created by 神龙网络 on 2025/11/9.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        
        // 检查授权状态
        let licenseStatus = LicenseService.checkLicenseStatus()
        
        if licenseStatus.valid {
            // 授权有效，直接进入主应用
            print("🔐 [App] 检测到有效授权，进入主应用")
            let mainViewController = ViewController()
            window?.rootViewController = mainViewController
        } else {
            // 需要验证授权
            print("🔐 [App] 需要验证授权")
            showLicenseVerification()
        }
        
        window?.makeKeyAndVisible()
    }
    
    private func showLicenseVerification() {
        let licenseVC = LicenseViewController()
        licenseVC.onLicenseVerified = { [weak self] in
            print("🔐 [App] 授权验证成功，切换到主应用")
            let mainViewController = ViewController()
            self?.window?.rootViewController = mainViewController
        }
        window?.rootViewController = licenseVC
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

