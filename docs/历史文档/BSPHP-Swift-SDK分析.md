# BSPHP Swift SDK 分析报告

> 基于官方 SDK 的完整分析和适配方案

## 📦 SDK 结构分析

### 1. 核心文件

```
BSphp-IOS-BSSwift/
├── demo/
│   └── BSSwift/
│       ├── ViewController.swift        # 主界面（调用入口）
│       ├── Bsphp/
│       │   └── YMBSTool.swift          # 核心验证工具类 ⭐
│       └── Lib/
│           ├── Alamofire/              # 网络请求库
│           └── SwiftyJSON/             # JSON 解析库
└── 说明/
    └── 图片说明（1-5.jpg）
```

### 2. 核心类：`YMBSTool.swift`

**功能概览**：
- ✅ **API 封装**：封装了 4 个常用 API
- ✅ **加密通信**：使用 DES3 加密
- ✅ **签名验证**：输入/输出签名验证（防劫持）
- ✅ **设备绑定**：使用 IDFA（广告标识符）
- ✅ **完整流程**：从获取 Session 到卡密验证

---

## 🔑 关键配置参数

```swift
class YMBSTool {
    // 1. 服务器地址（需要修改）
    static let pre: String = "http://app.bsphp.com/AppEn.php?appid=33321213&m=69e193655bd8a5449937c46fe8a843f6"
    
    // 2. 通信认证Key（在后台获取）
    static let mkey: String = "1ea569ee2f134714750cf28f525c05bd"
    
    // 3. 输入签名验证（在后台配置）
    static let ikey: String = "[KEY]in123456_ka"
    
    // 4. 输出签名验证（在后台配置）
    static let okey: String = "[KEY]to456789_ka"
    
    // 5. 数据加密密码（在后台配置）
    static let pkey: String = "asdfwetyhjuytrfd"
    
    // 6. 软件MD5（可选）
    static let rmd5: String = "xxxxx"
    
    // 7. 版本号
    static let appVersion: String = "v1.0"
}
```

---

## 🔐 加密和签名流程

### 1. 请求加密流程

```swift
// 步骤1: 参数字典 → URL 字符串
dict = {"api": "login.ic", "icid": "TEST001", ...}
↓
s = "api=login.ic&icid=TEST001&..."

// 步骤2: 加密密码 → MD5
pkey = "asdfwetyhjuytrfd"
↓
d = md5(pkey) = "xxxxx"

// 步骤3: DES3 加密数据
e = des3_encrypt(s, key: d, iv: "bsphp666")

// 步骤4: 生成签名
ss = "[KEY]in123456_ka".replace("[KEY]", e)
↓
sgin = md5(ss)

// 步骤5: 发送请求
POST {
    "json": "ok",
    "sgin": sgin,
    "parameter": urlEncode(e)
}
```

### 2. 响应解密流程

```swift
// 步骤1: 收到加密响应
response = "xxxxx" (加密的字符串)

// 步骤2: DES3 解密
decrypted = des3_decrypt(response, key: md5(pkey), iv: "bsphp666")

// 步骤3: 解析 JSON
json = JSON(decrypted)

// 步骤4: 验证签名
ins = "\(data)\(date)\(unix)\(microtime)\(appsafecode)"
re = "[KEY]to456789_ka".replace("[KEY]", ins)
ms = md5(re)

// 步骤5: 比对签名
if ms == json["response"]["sgin"] {
    // 签名正确，数据可信
} else {
    // 签名错误，数据被篡改
}
```

---

## 📱 完整验证流程

### SDK 的验证流程

```
1. 获取 BSphpSeSsL (Session)
   api_BSphpSeSsL_in()
   ↓
2. 获取版本信息
   api_v_in(session)
   ↓
3. 检查版本号
   if version == "v1.0" → 继续
   else → 退出
   ↓
4. 检查本地是否有卡密
   if UserDefaults 有 "oldCode" → 直接验证
   else → 弹窗输入
   ↓
5. 卡密验证
   api_login_ic(session, code, udid)
   ↓
6. 解析响应
   "01|1081|设备ID|验证数据|过期时间|..."
   ↓
7. 检查设备绑定
   if 设备ID == 本机UDID → 验证成功
   else → 提示"已绑定其他设备"
   ↓
8. 保存卡密到本地
   UserDefaults.save("oldCode")
   ↓
9. 显示公告
   api_gg_in(session)
```

---

## 🔧 核心 API 接口

### 1. 获取 Session

```swift
static func api_BSphpSeSsL_in(callback: ((JSON, [String: Any]) -> ())?) {
    var dic = [String: Any]()
    dic["api"] = "BSphpSeSsL.in"
    dic["date"] = fetchDate()
    dic["md5"] = rmd5
    dic["mutualkey"] = mkey
    
    fetchData(dic, callback: callback)
}
```

### 2. 获取版本信息

```swift
static func api_v_in(_ dict: JSON, callback:((JSON, [String: Any]) -> ())?) {
    var dic = [String: Any]()
    dic["api"] = "v.in"
    dic["BSphpSeSsL"] = dict["response"]["data"].stringValue
    dic["date"] = fetchDate()
    dic["md5"] = rmd5
    dic["mutualkey"] = mkey
    dic["appsafecode"] = fetchDate()
    
    fetchData(dic, callback: callback)
}
```

### 3. 卡密验证

```swift
static func api_login_ic(_ dict: JSON, code: String, udid: String, callback:((JSON, [String: Any]) -> ())?) {
    var dic = [String: Any]()
    dic["api"] = "login.ic"
    dic["BSphpSeSsL"] = dict["response"]["data"].stringValue
    dic["date"] = fetchDate()
    dic["md5"] = rmd5
    dic["mutualkey"] = mkey
    dic["appsafecode"] = fetchDate()
    dic["key"] = udid              // 设备标识
    dic["maxoror"] = udid          // 在线标记
    dic["icid"] = code             // 卡号
    
    fetchData(dic, callback: callback)
}
```

### 4. 获取公告

```swift
static func api_gg_in(_ dict: JSON, callback:((JSON, [String: Any]) -> ())?) {
    var dic = [String: Any]()
    dic["api"] = "gg.in"
    dic["BSphpSeSsL"] = dict["response"]["data"].stringValue
    dic["date"] = fetchDate()
    dic["md5"] = rmd5
    dic["mutualkey"] = mkey
    dic["appsafecode"] = fetchDate()
    
    fetchData(dic, callback: callback)
}
```

---

## 🎯 适配到我们的项目

### 方案对比

| 项目 | 官方 SDK | 我们之前的方案 | 最终方案 |
|------|---------|---------------|---------|
| **网络库** | Alamofire | URLSession | **Alamofire** ✅ |
| **JSON** | SwiftyJSON | Codable | **SwiftyJSON** ✅ |
| **加密** | DES3 + MD5 | 无 | **DES3 + MD5** ✅ |
| **签名** | 双向签名 | 无 | **双向签名** ✅ |
| **设备ID** | IDFA | IDFV | **IDFV** 🔄 |
| **UI** | UIAlertController | 自定义 ViewController | **自定义** ✅ |

### 需要修改的地方

1. **设备标识**：
   - 官方用 `IDFA`（广告标识符，需要用户授权）
   - 我们改用 `IDFV`（供应商标识符，无需授权）

2. **UI 界面**：
   - 官方用 `UIAlertController`（系统弹窗）
   - 我们改用自定义 `ViewController`（更美观）

3. **网络库**：
   - 官方包含完整 Alamofire 源码
   - 我们可以用 SPM 或 CocoaPods 安装

---

## ✅ 集成步骤

### 1. 添加依赖

**方式一：Swift Package Manager（推荐）**

```swift
// Package.swift 或 Xcode → File → Add Packages
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
    .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0")
]
```

**方式二：CocoaPods**

```ruby
# Podfile
pod 'Alamofire', '~> 5.8'
pod 'SwiftyJSON', '~> 5.0'
```

### 2. 文件清单

需要创建的文件：

```
WechatVideoReplacer/
├── Services/
│   ├── BSPHPService.swift          # BSPHP 核心服务（基于官方 SDK）
│   └── DESCrypto.swift             # DES3 加密工具
├── Utils/
│   ├── DeviceIdentifier.swift     # 设备标识（改用 IDFV）
│   ├── String+MD5.swift            # MD5 扩展
│   └── String+DES.swift            # DES 扩展
├── Models/
│   └── LicenseInfo.swift           # 授权信息
└── Views/
    └── LicenseViewController.swift # 卡密输入界面
```

### 3. 核心改进

#### 3.1 设备标识改进

```swift
// 官方 SDK（需要用户授权）
let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString

// 我们的改进（无需授权）
let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
```

#### 3.2 UI 改进

```swift
// 官方 SDK（系统弹窗）
UIAlertController.activetAlert(title, message: message, holder: "兑换码", btnTitle: "使用")

// 我们的改进（自定义界面）
let licenseVC = LicenseViewController()
licenseVC.modalPresentationStyle = .overFullScreen
present(licenseVC, animated: true)
```

---

## 📝 完整实现代码

### 文件 1: `Services/BSPHPService.swift`

> 基于官方 SDK 改写，保留加密和签名逻辑

```swift
import Foundation
import Alamofire
import SwiftyJSON

/// BSPHP API 枚举
enum BSPHPApi: String {
    case BSphpSeSsL = "BSphpSeSsL.in"
    case version = "v.in"
    case loginCard = "login.ic"
    case announcement = "gg.in"
}

/// BSPHP 验证服务
class BSPHPService {
    
    // MARK: - 配置（⚠️ 需要修改为你的配置）
    
    /// 服务器地址
    private static let serverURL = "https://你的域名.com/api"
    
    /// 通信认证 Key（在后台获取）
    private static let mutualKey = "YOUR_MUTUAL_KEY"
    
    /// 输入签名密钥（在后台配置）
    private static let inputKey = "[KEY]in123456_ka"
    
    /// 输出签名密钥（在后台配置）
    private static let outputKey = "[KEY]to456789_ka"
    
    /// 数据加密密码（在后台配置）
    private static let encryptKey = "YOUR_ENCRYPT_PASSWORD"
    
    /// 软件 MD5（可选）
    private static let appMD5 = ""
    
    /// 版本号
    private static let appVersion = "v1.0"
    
    // MARK: - API 接口
    
    /// 1. 获取 BSphpSeSsL (Session)
    static func getBSphpSeSsL(completion: @escaping (Result<JSON, Error>) -> Void) {
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.BSphpSeSsL.rawValue
        params["date"] = currentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        
        request(params, completion: completion)
    }
    
    /// 2. 获取版本信息
    static func getVersion(session: String, completion: @escaping (Result<JSON, Error>) -> Void) {
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.version.rawValue
        params["BSphpSeSsL"] = session
        params["date"] = currentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        params["appsafecode"] = currentTimestamp()
        
        request(params, completion: completion)
    }
    
    /// 3. 卡密验证
    static func verifyCard(
        session: String,
        cardNumber: String,
        deviceID: String,
        completion: @escaping (Result<JSON, Error>) -> Void
    ) {
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.loginCard.rawValue
        params["BSphpSeSsL"] = session
        params["date"] = currentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        params["appsafecode"] = currentTimestamp()
        params["key"] = deviceID
        params["maxoror"] = deviceID
        params["icid"] = cardNumber
        params["icpwd"] = ""  // 如果不需要密码则为空
        
        request(params, completion: completion)
    }
    
    /// 4. 获取公告
    static func getAnnouncement(session: String, completion: @escaping (Result<JSON, Error>) -> Void) {
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.announcement.rawValue
        params["BSphpSeSsL"] = session
        params["date"] = currentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        params["appsafecode"] = currentTimestamp()
        
        request(params, completion: completion)
    }
    
    // MARK: - 网络请求
    
    private static func request(
        _ params: [String: Any],
        completion: @escaping (Result<JSON, Error>) -> Void
    ) {
        // 1. 加密参数
        guard let encryptedParams = encryptParams(params) else {
            completion(.failure(NSError(domain: "BSPHP", code: -1, userInfo: [NSLocalizedDescriptionKey: "参数加密失败"])))
            return
        }
        
        print("🔐 发送请求: \(params["api"] ?? "")")
        
        // 2. 发送请求
        AF.request(
            serverURL,
            method: .post,
            parameters: encryptedParams,
            encoding: URLEncoding.default,
            headers: ["Accept": "application/json"]
        ).response { response in
            switch response.result {
            case .success(let data):
                guard let data = data else {
                    completion(.failure(NSError(domain: "BSPHP", code: -1, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                    return
                }
                
                // 3. 解密响应
                guard let json = decryptResponse(data, originalParams: params) else {
                    completion(.failure(NSError(domain: "BSPHP", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应解密失败"])))
                    return
                }
                
                print("✅ 响应成功: \(json["response"]["data"])")
                completion(.success(json))
                
            case .failure(let error):
                print("❌ 请求失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 加密参数
    
    private static func encryptParams(_ params: [String: Any]) -> [String: Any]? {
        // 1. 字典 → URL 字符串
        let paramString = formatDictToURLString(params)
        
        // 2. 加密密码 → MD5
        let keyMD5 = encryptKey.md5()
        
        // 3. DES3 加密
        guard let encrypted = paramString.des3Encrypt(key: keyMD5, iv: "bsphp666") else {
            return nil
        }
        
        // 4. 生成签名
        let signString = inputKey.replacingOccurrences(of: "[KEY]", with: encrypted)
        let signature = signString.md5()
        
        // 5. URL 编码
        guard let urlEncoded = encrypted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        return [
            "json": "ok",
            "sgin": signature,
            "parameter": urlEncoded
        ]
    }
    
    // MARK: - 解密响应
    
    private static func decryptResponse(_ data: Data, originalParams: [String: Any]) -> JSON? {
        // 1. Data → String
        guard let encryptedString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // 2. 加密密码 → MD5
        let keyMD5 = encryptKey.md5()
        
        // 3. DES3 解密
        guard let decrypted = encryptedString.des3Decrypt(key: keyMD5, iv: "bsphp666") else {
            return nil
        }
        
        // 4. 解析 JSON
        guard let jsonData = decrypted.data(using: .utf8) else {
            return nil
        }
        
        let json = try? JSON(data: jsonData)
        guard let json = json else {
            return nil
        }
        
        // 5. 验证签名
        let response = json["response"]
        let data = response["data"].stringValue
        let date = response["date"].stringValue
        let unix = response["unix"].stringValue
        let microtime = response["microtime"].stringValue
        let appsafecode = response["appsafecode"].stringValue
        let receivedSign = response["sgin"].stringValue
        
        let signString = "\(data)\(date)\(unix)\(microtime)\(appsafecode)"
        let fullString = outputKey.replacingOccurrences(of: "[KEY]", with: signString)
        let calculatedSign = fullString.md5()
        
        if calculatedSign == receivedSign {
            print("✅ 签名验证通过")
            
            // 6. 验证防劫持码
            if let sentSafecode = originalParams["appsafecode"] as? String {
                if appsafecode != sentSafecode {
                    print("⚠️ 防劫持码不匹配")
                    return nil
                }
            }
            
            return json
        } else {
            print("❌ 签名验证失败")
            return nil
        }
    }
    
    // MARK: - 工具方法
    
    /// 获取当前时间戳（毫秒）
    private static func currentTimestamp() -> String {
        return String(Int64(Date().timeIntervalSince1970 * 1000))
    }
    
    /// 字典转 URL 字符串
    private static func formatDictToURLString(_ dict: [String: Any]) -> String {
        return dict.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }
}
```

---

## 🎨 使用示例

### 完整验证流程

```swift
// 1. 获取 Session
BSPHPService.getBSphpSeSsL { result in
    switch result {
    case .success(let sessionJSON):
        let session = sessionJSON["response"]["data"].stringValue
        
        // 2. 获取版本信息
        BSPHPService.getVersion(session: session) { result in
            switch result {
            case .success(let versionJSON):
                let version = versionJSON["response"]["data"].stringValue.components(separatedBy: "|")[0]
                
                if version == "v1.0" {
                    // 3. 卡密验证
                    let deviceID = DeviceIdentifier.getDeviceKey()
                    BSPHPService.verifyCard(session: session, cardNumber: "TEST001", deviceID: deviceID) { result in
                        switch result {
                        case .success(let loginJSON):
                            let data = loginJSON["response"]["data"].stringValue
                            let parts = data.components(separatedBy: "|")
                            
                            if parts[0] == "01" && parts[1] == "1081" {
                                print("✅ 验证成功")
                                print("设备ID: \(parts[2])")
                                print("过期时间: \(parts[4])")
                                
                                // 保存授权
                                // ...
                            }
                            
                        case .failure(let error):
                            print("❌ 验证失败: \(error)")
                        }
                    }
                } else {
                    print("❌ 版本过期")
                }
                
            case .failure(let error):
                print("❌ 获取版本失败: \(error)")
            }
        }
        
    case .failure(let error):
        print("❌ 获取 Session 失败: \(error)")
    }
}
```

---

## 📌 总结

### 官方 SDK 的优点
- ✅ 完整的加密和签名机制
- ✅ 防劫持保护
- ✅ 经过实际验证的代码
- ✅ 详细的参数说明

### 我们的改进
- ✅ 使用 IDFV 代替 IDFA（无需授权）
- ✅ 自定义 UI 界面（更美观）
- ✅ 模块化设计（更易维护）
- ✅ 完整的错误处理

### 下一步
1. 创建所有必需的 Swift 文件
2. 添加 DES3 和 MD5 扩展
3. 创建自定义卡密输入界面
4. 集成到主应用流程

---

**文档版本**: v1.0  
**创建日期**: 2025-11-11  
**基于**: BSPHP 官方 Swift SDK (2022-08-23)
