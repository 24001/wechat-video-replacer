# BSPHP 卡密验证集成方案

> 为微信视频替换工具添加 BSPHP 网络验证功能

## 📋 目录

1. [方案概述](#方案概述)
2. [API 接口文档](#api-接口文档)
3. [代码实现](#代码实现)
4. [使用流程](#使用流程)
5. [服务器配置](#服务器配置)

---

## 1. 方案概述

### 1.1 验证流程

```
应用启动
  ↓
检查本地授权状态
  ├─ 已验证 → 进入主界面
  └─ 未验证 → 弹出卡密输入框
       ↓
用户输入卡号和密码
  ↓
调用 BSPHP API 验证
  ├─ 成功 → 保存授权信息 → 进入主界面
  └─ 失败 → 显示错误 → 重新输入
```

### 1.2 使用的 API

**接口名称**: 卡模式用户登录验证  
**API 地址**: `login.ic`  
**完整 URL**: `https://你的域名/api/login.ic`

**返回格式**:
```
成功: "01|1081|绑定key|登录成功验证数据|到期时间|||||"
失败: "03|xxxx|错误信息|||||..."
```

---

## 2. API 接口文档

### 2.1 请求参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `api` | String | ✅ | 接口名称，固定值: `login.ic` |
| `BSphpSeSsL` | String | ✅ | 连接 Cookies，从 `BSphpSeSsL.in` 获取 |
| `date` | String | ⚪ | 服务器时间（超时验证） |
| `mutualkey` | String | ✅ | 通信认证 Key（软件标识） |
| `appsafecode` | String | ⚪ | 封包劫持检测码 |
| `md5` | String | ⚪ | 程序 MD5 |
| `icid` | String | ✅ | 卡号（用户输入） |
| `icpwd` | String | ✅ | 卡密（用户输入） |
| `key` | String | ✅ | 绑定特征（设备标识） |
| `maxoror` | String | ✅ | 在线标记（唯一设备标识） |

### 2.2 返回数据

**成功格式**:
```
"01|1081|绑定key|验证数据|到期时间|||||"
```

**返回字段说明**:
- `[0]`: 固定 "01" (成功标识)
- `[1]`: 固定 "1081" (登录成功代号)
- `[2]`: 绑定的设备 key
- `[3]`: 用户验证数据
- `[4]`: VIP 到期时间 (格式: `2025-12-31 23:59:59`)

**失败格式**:
```
"03|xxxx|错误信息|||||..."
```

常见错误码:
- `03|1002`: 卡号不存在
- `03|1003`: 卡密错误
- `03|1004`: 卡已过期
- `03|1005`: 卡已被绑定到其他设备

---

## 3. 代码实现

### 3.1 文件结构

```
WechatVideoReplacer/
├── Models/
│   └── LicenseInfo.swift          # 授权信息模型
├── Services/
│   └── BSPHPService.swift         # BSPHP API 服务
├── Utils/
│   ├── LicenseManager.swift       # 授权管理器
│   └── DeviceIdentifier.swift    # 设备标识生成
└── Views/
    └── LicenseViewController.swift # 卡密输入界面
```

### 3.2 模型定义

**文件**: `Models/LicenseInfo.swift`

```swift
import Foundation

/// 授权信息
struct LicenseInfo: Codable {
    let cardNumber: String          // 卡号
    let deviceKey: String           // 绑定的设备标识
    let verifyData: String          // 验证数据
    let expireDate: String          // 到期时间
    let verifiedAt: Date            // 验证时间
    
    /// 是否已过期
    var isExpired: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let expireDate = formatter.date(from: self.expireDate) else {
            return true
        }
        
        return Date() > expireDate
    }
    
    /// 格式化显示到期时间
    var expireDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let date = formatter.date(from: expireDate) else {
            return "未知"
        }
        
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

/// API 响应
struct BSPHPResponse {
    let success: Bool               // 是否成功
    let code: String                // 状态码
    let message: String             // 消息
    let data: [String]              // 数据数组
    
    /// 从字符串解析响应
    static func parse(_ responseString: String) -> BSPHPResponse {
        let parts = responseString.components(separatedBy: "|")
        
        guard parts.count >= 3 else {
            return BSPHPResponse(
                success: false,
                code: "0",
                message: "响应格式错误",
                data: []
            )
        }
        
        let success = parts[0] == "01"
        let code = parts[1]
        let message = success ? "验证成功" : parts[2]
        
        return BSPHPResponse(
            success: success,
            code: code,
            message: message,
            data: parts
        )
    }
}
```

### 3.3 设备标识生成

**文件**: `Utils/DeviceIdentifier.swift`

```swift
import UIKit

/// 设备标识生成器
class DeviceIdentifier {
    
    /// 获取唯一设备标识
    static func getDeviceKey() -> String {
        // 使用 IDFV (identifierForVendor)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }
        
        // 备用方案：生成随机 UUID 并持久化
        if let savedKey = UserDefaults.standard.string(forKey: "deviceKey") {
            return savedKey
        }
        
        let newKey = UUID().uuidString
        UserDefaults.standard.set(newKey, forKey: "deviceKey")
        return newKey
    }
    
    /// 获取在线标记（每次都生成新的）
    static func getOnlineMark() -> String {
        return "\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
    }
}
```

### 3.4 BSPHP 服务

**文件**: `Services/BSPHPService.swift`

```swift
import Foundation

/// BSPHP 验证服务
class BSPHPService {
    
    // MARK: - 配置（需要修改）
    
    /// 服务器域名
    private static let baseURL = "https://你的域名.com"
    
    /// 软件标识（mutualkey）- 在 BSPHP 后台配置
    private static let softwareKey = "YOUR_SOFTWARE_KEY"
    
    // MARK: - API 接口
    
    /// 获取 BSphpSeSsL (连接 Cookies)
    static func getBSphpSeSsL(completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/api/BSphpSeSsL.in")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "api=BSphpSeSsL.in&mutualkey=\(softwareKey)"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let responseString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "BSPHPService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析响应"])))
                return
            }
            
            // 响应格式: "01|xxxx|BSphpSeSsL值|..."
            let parts = responseString.components(separatedBy: "|")
            if parts.count >= 3 && parts[0] == "01" {
                completion(.success(parts[2]))
            } else {
                completion(.failure(NSError(domain: "BSPHPService", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 BSphpSeSsL 失败"])))
            }
        }.resume()
    }
    
    /// 卡密验证
    static func verifyCard(
        cardNumber: String,
        cardPassword: String,
        completion: @escaping (Result<LicenseInfo, Error>) -> Void
    ) {
        // 1. 先获取 BSphpSeSsL
        getBSphpSeSsL { result in
            switch result {
            case .success(let bsphpSession):
                // 2. 使用 BSphpSeSsL 进行卡密验证
                performCardVerify(
                    cardNumber: cardNumber,
                    cardPassword: cardPassword,
                    bsphpSession: bsphpSession,
                    completion: completion
                )
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 执行卡密验证请求
    private static func performCardVerify(
        cardNumber: String,
        cardPassword: String,
        bsphpSession: String,
        completion: @escaping (Result<LicenseInfo, Error>) -> Void
    ) {
        let url = URL(string: "\(baseURL)/api/login.ic")!
        
        let deviceKey = DeviceIdentifier.getDeviceKey()
        let onlineMark = DeviceIdentifier.getOnlineMark()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 构建请求参数
        let params = [
            "api": "login.ic",
            "BSphpSeSsL": bsphpSession,
            "mutualkey": softwareKey,
            "icid": cardNumber,
            "icpwd": cardPassword,
            "key": deviceKey,
            "maxoror": onlineMark
        ]
        
        let body = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        print("🔐 验证请求:")
        print("  卡号: \(cardNumber)")
        print("  设备: \(deviceKey)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let responseString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "BSPHPService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析响应"])))
                return
            }
            
            print("📡 服务器响应: \(responseString)")
            
            // 解析响应
            let response = BSPHPResponse.parse(responseString)
            
            if response.success {
                // 验证成功
                let licenseInfo = LicenseInfo(
                    cardNumber: cardNumber,
                    deviceKey: response.data[2],  // 绑定key
                    verifyData: response.data[3], // 验证数据
                    expireDate: response.data[4], // 到期时间
                    verifiedAt: Date()
                )
                
                print("✅ 验证成功!")
                print("  到期时间: \(licenseInfo.expireDate)")
                
                completion(.success(licenseInfo))
            } else {
                // 验证失败
                let errorMessage = response.message
                print("❌ 验证失败: \(errorMessage)")
                
                completion(.failure(NSError(
                    domain: "BSPHPService",
                    code: Int(response.code) ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )))
            }
        }.resume()
    }
}
```

### 3.5 授权管理器

**文件**: `Utils/LicenseManager.swift`

```swift
import Foundation

/// 授权管理器
class LicenseManager {
    
    static let shared = LicenseManager()
    private init() {}
    
    private let storageKey = "licenseInfo"
    
    // MARK: - 持久化
    
    /// 保存授权信息
    func save(_ license: LicenseInfo) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(license) {
            UserDefaults.standard.set(data, forKey: storageKey)
            UserDefaults.standard.synchronize()
            print("✅ 授权信息已保存")
        }
    }
    
    /// 加载授权信息
    func load() -> LicenseInfo? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(LicenseInfo.self, from: data)
    }
    
    /// 清除授权信息
    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.synchronize()
        print("🗑️ 授权信息已清除")
    }
    
    // MARK: - 验证状态
    
    /// 检查是否已授权且未过期
    func isValid() -> Bool {
        guard let license = load() else {
            return false
        }
        
        // 检查是否过期
        if license.isExpired {
            print("⚠️ 授权已过期")
            return false
        }
        
        print("✅ 授权有效，到期时间: \(license.expireDate)")
        return true
    }
    
    /// 获取授权信息摘要
    func getSummary() -> String? {
        guard let license = load() else {
            return nil
        }
        
        return """
        卡号: \(license.cardNumber)
        到期时间: \(license.expireDateFormatted)
        设备: \(license.deviceKey.prefix(8))...
        """
    }
}
```

### 3.6 卡密输入界面

**文件**: `Views/LicenseViewController.swift`

```swift
import UIKit

/// 卡密输入界面
class LicenseViewController: UIViewController {
    
    // MARK: - UI 组件
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 10
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "软件授权验证"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private let cardNumberTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "请输入卡号"
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 16)
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        return field
    }()
    
    private let cardPasswordTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "请输入卡密"
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 16)
        field.isSecureTextEntry = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        return field
    }()
    
    private let verifyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("立即验证", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - 回调
    
    var onVerifySuccess: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(cardNumberTextField)
        containerView.addSubview(cardPasswordTextField)
        containerView.addSubview(verifyButton)
        containerView.addSubview(statusLabel)
        containerView.addSubview(activityIndicator)
        
        // 布局
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardNumberTextField.translatesAutoresizingMaskIntoConstraints = false
        cardPasswordTextField.translatesAutoresizingMaskIntoConstraints = false
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 400),
            containerView.heightAnchor.constraint(equalToConstant: 350),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Card Number
            cardNumberTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            cardNumberTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            cardNumberTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            cardNumberTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Card Password
            cardPasswordTextField.topAnchor.constraint(equalTo: cardNumberTextField.bottomAnchor, constant: 20),
            cardPasswordTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            cardPasswordTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            cardPasswordTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Verify Button
            verifyButton.topAnchor.constraint(equalTo: cardPasswordTextField.bottomAnchor, constant: 30),
            verifyButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            verifyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            verifyButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            
            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: verifyButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: verifyButton.centerYAnchor)
        ])
    }
    
    private func setupActions() {
        verifyButton.addTarget(self, action: #selector(handleVerify), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func handleVerify() {
        guard let cardNumber = cardNumberTextField.text?.trimmingCharacters(in: .whitespaces),
              !cardNumber.isEmpty else {
            showStatus("请输入卡号", isError: true)
            return
        }
        
        guard let cardPassword = cardPasswordTextField.text?.trimmingCharacters(in: .whitespaces),
              !cardPassword.isEmpty else {
            showStatus("请输入卡密", isError: true)
            return
        }
        
        // 开始验证
        setVerifying(true)
        showStatus("正在验证，请稍候...", isError: false)
        
        BSPHPService.verifyCard(cardNumber: cardNumber, cardPassword: cardPassword) { [weak self] result in
            DispatchQueue.main.async {
                self?.setVerifying(false)
                
                switch result {
                case .success(let license):
                    // 保存授权信息
                    LicenseManager.shared.save(license)
                    
                    // 显示成功
                    self?.showStatus("验证成功！到期时间: \(license.expireDateFormatted)", isError: false)
                    
                    // 延迟关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.dismiss(animated: true) {
                            self?.onVerifySuccess?()
                        }
                    }
                    
                case .failure(let error):
                    self?.showStatus("验证失败: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func setVerifying(_ isVerifying: Bool) {
        cardNumberTextField.isEnabled = !isVerifying
        cardPasswordTextField.isEnabled = !isVerifying
        verifyButton.isEnabled = !isVerifying
        verifyButton.alpha = isVerifying ? 0.5 : 1.0
        
        if isVerifying {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
    
    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
    }
}
```

### 3.7 集成到主应用

**修改**: `ViewController.swift` 或 `AppDelegate.swift`

```swift
import UIKit

class ViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 检查授权
        checkLicense()
    }
    
    private func checkLicense() {
        if LicenseManager.shared.isValid() {
            // 授权有效，显示主界面
            print("✅ 授权有效")
            setupMainUI()
        } else {
            // 授权无效或未验证，显示卡密输入界面
            print("⚠️ 需要验证授权")
            showLicenseInput()
        }
    }
    
    private func showLicenseInput() {
        let licenseVC = LicenseViewController()
        licenseVC.modalPresentationStyle = .overFullScreen
        licenseVC.modalTransitionStyle = .crossDissolve
        
        licenseVC.onVerifySuccess = { [weak self] in
            // 验证成功后显示主界面
            self?.setupMainUI()
        }
        
        present(licenseVC, animated: true)
    }
    
    private func setupMainUI() {
        // 设置主界面...
        print("🚀 进入主界面")
        
        // 显示授权信息（可选）
        if let summary = LicenseManager.shared.getSummary() {
            print("📄 授权信息:\n\(summary)")
        }
    }
}
```

---

## 4. 使用流程

### 4.1 开发者配置

1. **部署 BSPHP 服务器**
   - 购买或搭建 BSPHP 验证系统
   - 配置域名和 SSL 证书

2. **配置软件信息**
   - 在 BSPHP 后台添加软件
   - 获取 `mutualkey`（软件标识）

3. **修改代码配置**
   ```swift
   // BSPHPService.swift
   private static let baseURL = "https://你的域名.com"
   private static let softwareKey = "YOUR_SOFTWARE_KEY"
   ```

4. **生成卡密**
   - 在 BSPHP 后台制卡
   - 设置卡密、到期时间等

### 4.2 用户使用

1. **首次启动**
   - 应用弹出卡密输入框
   - 用户输入卡号和卡密
   - 点击"立即验证"

2. **验证过程**
   - 应用连接服务器验证
   - 显示"正在验证，请稍候..."
   - 验证成功后保存授权信息

3. **后续使用**
   - 应用自动加载本地授权
   - 无需重复输入卡密
   - 到期后需要重新验证

---

## 5. 服务器配置

### 5.1 BSPHP 后台配置

1. **软件设置**
   - 软件名称: 微信视频替换工具
   - 验证模式: 卡模式
   - 绑定验证: 启用（防止卡密共享）

2. **制卡设置**
   - 卡密长度: 16-32 位
   - 有效期: 根据需求（如 30天、1年）
   - 是否需要密码: 建议启用

3. **安全设置**
   - 启用设备绑定
   - 启用重复登录检测
   - 设置合理的超时时间

### 5.2 测试流程

1. **生成测试卡**
   ```
   卡号: TEST20250111001
   卡密: testpassword123
   有效期: 2025-12-31
   ```

2. **测试验证**
   - 运行应用
   - 输入测试卡号和密码
   - 检查验证结果
   - 查看后台日志

3. **测试过期**
   - 修改后台卡密到期时间
   - 重启应用检查是否提示过期

---

## 6. 常见问题

### Q1: 验证失败怎么办？

**检查清单**:
- ✅ 服务器域名是否正确
- ✅ `mutualkey` 是否配置正确
- ✅ 卡号和卡密是否输入正确
- ✅ 网络连接是否正常
- ✅ 服务器是否正常运行

### Q2: 如何实现离线验证？

可以设置**宽限期**:
```swift
// 在 LicenseManager.isValid() 中添加
let daysSinceVerify = Date().timeIntervalSince(license.verifiedAt) / 86400
if daysSinceVerify > 7 {
    // 超过7天未联网验证，要求重新验证
    return false
}
```

### Q3: 如何防止破解？

**建议措施**:
1. 代码混淆（使用工具如 SwiftShield）
2. 加密存储授权信息
3. 定期心跳验证（使用 `timeout.ic` 接口）
4. 检测越狱/调试环境
5. 服务端日志监控异常行为

### Q4: 如何更新卡密？

**方案1**: 清除本地授权
```swift
// 在设置界面添加按钮
LicenseManager.shared.clear()
// 重启应用即可重新输入
```

**方案2**: 添加"更换卡密"功能
- 在主界面添加按钮
- 点击后显示卡密输入界面
- 验证成功后覆盖旧的授权信息

---

## 7. 完整示例

### 7.1 最简实现

如果你只想快速集成，这是最小化代码：

```swift
// 1. 在 AppDelegate 或 SceneDelegate 中
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // 检查授权
    if !LicenseManager.shared.isValid() {
        // 显示卡密输入界面
        let licenseVC = LicenseViewController()
        window?.rootViewController = licenseVC
    } else {
        // 显示主界面
        let mainVC = ViewController()
        window?.rootViewController = mainVC
    }
    
    return true
}

// 2. 在 LicenseViewController 验证成功后
licenseVC.onVerifySuccess = {
    let mainVC = ViewController()
    window?.rootViewController = mainVC
}
```

### 7.2 演示视频流程

1. 应用启动 → 弹出卡密框
2. 输入卡号: `TEST001`
3. 输入卡密: `password123`
4. 点击"立即验证"
5. 显示"正在验证..."
6. 成功 → "验证成功！到期时间: 2025年12月31日"
7. 自动跳转主界面

---

## 8. 总结

### ✅ 优点

- **简单易用**: 用户只需输入卡密即可
- **无需注册**: 不需要账号系统
- **离线友好**: 验证后可离线使用
- **灵活控制**: 可远程管理授权

### ⚠️ 注意事项

- 需要搭建 BSPHP 服务器（成本投入）
- 需要维护卡密系统
- 防破解需要额外措施
- 网络验证依赖服务器稳定性

---

**文档版本**: v1.0  
**创建日期**: 2025-11-11  
**适用项目**: 微信视频替换工具
