//
//  LicenseViewController.swift
//  WechatVideoReplacer
//
//  卡密验证界面 - 使用 iOS 原生 UIAlertController 样式
//

import UIKit

/// 卡密验证界面（iOS 原生样式）
class LicenseViewController: UIViewController {
    
    // MARK: - 回调
    
    var onSuccess: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // 延迟显示，确保界面已加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showLicenseAlert()
        }
    }
    
    // MARK: - 显示原生弹窗
    
    private func showLicenseAlert() {
        let alert = UIAlertController(
            title: "卡密验证",
            message: DeviceIdentifier.getDeviceInfo(),
            preferredStyle: .alert
        )
        
        // 添加卡密输入框
        alert.addTextField { textField in
            textField.placeholder = "请输入卡密"
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }
        
        // 验证按钮
        let verifyAction = UIAlertAction(title: "验证", style: .default) { [weak self, weak alert] _ in
            guard let cardNumber = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !cardNumber.isEmpty else {
                self?.showError("请输入卡密") {
                    self?.showLicenseAlert()
                }
                return
            }
            
            self?.verifyCard(cardNumber)
        }
        
        // 购买卡密按钮（可选）
        let buyAction = UIAlertAction(title: "购买卡密", style: .default) { [weak self] _ in
            // 这里可以打开购买页面或显示联系方式
            self?.showBuyInfo()
        }
        
        // 取消按钮（退出应用）
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            // 不要使用 exit(0)，而是通知系统正常退出
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        }
        
        alert.addAction(verifyAction)
        alert.addAction(buyAction)
        alert.addAction(cancelAction)
        
        // 设置验证为默认操作
        alert.preferredAction = verifyAction
        
        present(alert, animated: true)
    }
    
    // MARK: - 验证卡密
    
    private func verifyCard(_ cardNumber: String) {
        // 显示加载提示
        let loadingAlert = UIAlertController(
            title: "验证中",
            message: "正在连接服务器验证...\n\n",
            preferredStyle: .alert
        )
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        loadingAlert.view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: loadingAlert.view.bottomAnchor, constant: -40)
        ])
        
        present(loadingAlert, animated: true)
        
        print("\n" + String(repeating: "=", count: 60))
        print("🔐 [License] 用户开始验证")
        print("   - 卡密: \(cardNumber)")
        print(String(repeating: "=", count: 60))
        
        // 开始验证
        BSPHPService.fullVerify(cardNumber: cardNumber, cardPassword: "") { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let license):
                        // 保存授权信息
                        LicenseManager.shared.save(license)
                        
                        print("\n" + String(repeating: "=", count: 60))
                        print("✅ [License] 验证成功！")
                        print("   - 卡密: \(license.cardNumber)")
                        print("   - 到期: \(license.expireDate)")
                        print("   - 剩余: \(license.remainingDays) 天")
                        print(String(repeating: "=", count: 60) + "\n")
                        
                        // 显示成功提示
                        self?.showSuccess(
                            "验证成功！\n到期时间: \(license.expireDateFormatted)\n剩余 \(license.remainingDays) 天"
                        )
                        
                    case .failure(let error):
                        print("\n" + String(repeating: "=", count: 60))
                        print("❌ [License] 验证失败")
                        print("   - 错误: \(error.localizedDescription)")
                        print(String(repeating: "=", count: 60) + "\n")

                        // 显示简洁的用户友好错误信息
                        self?.showError(error.localizedDescription) {
                            self?.showLicenseAlert()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 显示成功
    
    private func showSuccess(_ message: String) {
        let alert = UIAlertController(
            title: "✅ 验证成功",
            message: message,
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "进入应用", style: .default) { [weak self] _ in
            // 震动反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // 调用成功回调
            self?.onSuccess?()
        }
        
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    // MARK: - 显示错误
    
    private func showError(_ message: String, retry: @escaping () -> Void) {
        // 震动反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        let alert = UIAlertController(
            title: "验证失败",
            message: message,
            preferredStyle: .alert
        )
        
        let retryAction = UIAlertAction(title: "重试", style: .default) { _ in
            retry()
        }
        
        let cancelAction = UIAlertAction(title: "退出", style: .cancel) { [weak self] _ in
            // 不要使用 exit(0)，而是通知系统正常退出
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        }
        
        alert.addAction(retryAction)
        alert.addAction(cancelAction)
        alert.preferredAction = retryAction
        
        present(alert, animated: true)
    }
    
    // MARK: - 显示购买信息
    
    private func showBuyInfo() {
        let alert = UIAlertController(
            title: "购买卡密",
            message: "请联系客服获取卡密\n或访问官网购买",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "知道了", style: .default) { [weak self] _ in
            self?.showLicenseAlert()
        }
        
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}
