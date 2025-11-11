import UIKit

/**
 * 功能描述: 卡密验证界面
 */
class LicenseViewController: UIViewController {
    
    // MARK: - UI 组件
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "🔐 软件授权验证"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "请输入您的授权卡密以继续使用"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let cardCodeTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "请输入卡密"
        textField.borderStyle = .roundedRect
        textField.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        textField.textAlignment = .center
        textField.autocapitalizationType = .allCharacters
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let verifyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("验证授权", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let deviceInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - 属性
    
    var onLicenseVerified: (() -> Void)?
    private var isVerifying = false
    
    // MARK: - 生命周期
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDeviceInfo()
        checkExistingLicense()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cardCodeTextField.becomeFirstResponder()
    }
    
    // MARK: - UI 设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 添加视图
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(cardCodeTextField)
        view.addSubview(verifyButton)
        view.addSubview(statusLabel)
        view.addSubview(activityIndicator)
        view.addSubview(deviceInfoLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            // 副标题
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            // 卡密输入框
            cardCodeTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 60),
            cardCodeTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            cardCodeTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            cardCodeTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // 验证按钮
            verifyButton.topAnchor.constraint(equalTo: cardCodeTextField.bottomAnchor, constant: 30),
            verifyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            verifyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            verifyButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            // 加载指示器
            activityIndicator.centerXAnchor.constraint(equalTo: verifyButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: verifyButton.centerYAnchor),
            
            // 设备信息
            deviceInfoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            deviceInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            deviceInfoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // 添加按钮动作
        verifyButton.addTarget(self, action: #selector(verifyButtonTapped), for: .touchUpInside)
        
        // 添加文本框监听
        cardCodeTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    }
    
    private func setupDeviceInfo() {
        let deviceID = getDeviceID()
        deviceInfoLabel.text = "设备标识: \(deviceID)\n用于绑定授权，请妥善保管"
    }
    
    private func checkExistingLicense() {
        let status = LicenseService.checkLicenseStatus()
        if status.valid {
            showSuccess("检测到有效授权，正在进入应用...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.onLicenseVerified?()
            }
        } else if status.expired {
            statusLabel.text = "⚠️ 授权已过期，请重新验证"
            statusLabel.textColor = .systemOrange
        }
    }
    
    // MARK: - 按钮动作
    
    @objc private func verifyButtonTapped() {
        guard !isVerifying else { return }
        
        let cardCode = cardCodeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard !cardCode.isEmpty else {
            showError("请输入卡密")
            return
        }
        
        guard cardCode.count >= 8 else {
            showError("卡密长度不能少于8位")
            return
        }
        
        startVerification(cardCode: cardCode)
    }
    
    @objc private func textFieldChanged() {
        // 自动转换为大写
        if let text = cardCodeTextField.text {
            cardCodeTextField.text = text.uppercased()
        }
        
        // 清除之前的错误信息
        if statusLabel.textColor == .systemRed {
            statusLabel.text = ""
        }
    }
    
    // MARK: - 验证逻辑
    
    private func startVerification(cardCode: String) {
        isVerifying = true
        updateUI(verifying: true)
        
        LicenseService.verifyLicense(cardCode: cardCode) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleVerificationResult(result)
            }
        }
    }
    
    private func handleVerificationResult(_ result: Result<LicenseInfo, LicenseError>) {
        isVerifying = false
        updateUI(verifying: false)
        
        switch result {
        case .success(let info):
            showSuccess("✅ 验证成功！\n授权类型: \(info.cardType)\n剩余天数: \(info.remainingDays)天")
            
            // 延迟进入主应用
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.onLicenseVerified?()
            }
            
        case .failure(let error):
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - UI 更新
    
    private func updateUI(verifying: Bool) {
        if verifying {
            activityIndicator.startAnimating()
            verifyButton.setTitle("", for: .normal)
            verifyButton.isEnabled = false
            cardCodeTextField.isEnabled = false
            statusLabel.text = "正在验证授权，请稍候..."
            statusLabel.textColor = .systemBlue
        } else {
            activityIndicator.stopAnimating()
            verifyButton.setTitle("验证授权", for: .normal)
            verifyButton.isEnabled = true
            cardCodeTextField.isEnabled = true
        }
    }
    
    private func showSuccess(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .systemGreen
    }
    
    private func showError(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        
        // 震动反馈
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - 工具方法
    
    private func getDeviceID() -> String {
        let udid = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        return String(udid.prefix(8))
    }
}
