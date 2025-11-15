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

        // 检查授权
        if LicenseManager.shared.isValid() {
            // 授权有效，直接进入主界面
            window?.rootViewController = ViewController()
            print("✅ [授权] 授权有效，进入主界面")
        } else {
            // 授权无效，显示授权界面
            let licenseVC = LicenseViewController()
            licenseVC.onSuccess = { [weak self] in
                // 授权成功后，切换到主界面
                self?.window?.rootViewController = ViewController()
                print("✅ [授权] 授权验证成功，进入主界面")
            }
            window?.rootViewController = licenseVC
            print("⚠️ [授权] 授权无效，显示授权界面")
        }
        
        window?.makeKeyAndVisible()
    }
    
    // MARK: - 完整授权测试
    
    func testEncryption() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 [测试] 开始完整授权测试")
        print(String(repeating: "=", count: 60))
        
        // 使用真实卡密测试
        let cardNumber = "slPnNu6QyzxeRZvz2iVIXDT6gA"
        print("\n1️⃣ 测试卡密: \(cardNumber)")
        
        // 调用完整验证流程
        BSPHPService.fullVerify(cardNumber: cardNumber, cardPassword: "") { result in
            print("\n" + String(repeating: "=", count: 60))
            switch result {
            case .success(let license):
                print("✅ [测试] 验证成功！")
                print("   卡号: \(license.cardNumber)")
                print("   设备: \(license.deviceKey)")
                print("   过期: \(license.expireDate)")
                print("   剩余天数: \(license.remainingDays)")
                
                // 保存授权信息
                LicenseManager.shared.save(license)
                print("✅ [测试] 授权已保存")
                
            case .failure(let error):
                print("❌ [测试] 验证失败: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   错误码: \(nsError.code)")
                    print("   错误域: \(nsError.domain)")
                    if let userInfo = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                        print("   详细信息: \(userInfo)")
                    }
                }
            }
            print(String(repeating: "=", count: 60))
            print("\n")
        }
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

