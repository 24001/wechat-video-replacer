//
//  BSPHPService.swift
//  WechatVideoReplacer
//
//  BSPHP 网络验证服务
//  基于官方 Swift SDK 改写
//

import Foundation
import CommonCrypto

/// BSPHP API 枚举
enum BSPHPApi: String {
    case BSphpSeSsL = "BSphpSeSsL.in"
    case version = "v.in"
    case loginCard = "login.ic"
    case announcement = "gg.in"
}

/// BSPHP 验证服务
class BSPHPService {
    
    // MARK: - 配置参数

    /// 服务器地址（完整 URL，包含 appid 和 m 参数）
    private static let serverURL = "https://km.shenl.vip/AppEn.php?appid=57834999&m=2fd21180c32b6b8ca39e7a59829f960e"

    /// 软件代号
    private static let softwareID = "57834999"

    /// 通信认证 Key
    private static let mutualKey = "00554c02b166c048449ade6c7e127c68"

    /// 输入签名密钥（接收 Sgin 验证）
    private static let inputSignKey = "578[KEY]349"

    /// 输出签名密钥（输出 Sgin 验证）
    private static let outputSignKey = "slwl[KEY]24001"

    /// 数据加密密码
    private static let encryptPassword = "M1K1EzwSTih4wzq5GB"
    
    /// 软件 MD5（可选，后台为空则不验证）
    private static let appMD5 = ""
    
    /// 软件版本号
    private static let appVersion = "v1.0"
    
    // MARK: - API 接口
    
    /// 1. 获取 BSphpSeSsL (Session)
    static func getBSphpSeSsL(completion: @escaping (Result<String, Error>) -> Void) {
        print("🔐 [BSPHP] 获取 Session...")
        
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.BSphpSeSsL.rawValue
        params["date"] = getCurrentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        
        request(params) { result in
            switch result {
            case .success(let json):
                let session = json["response"]["data"].stringValue
                print("✅ [BSPHP] Session 获取成功")
                completion(.success(session))
                
            case .failure(let error):
                print("❌ [BSPHP] Session 获取失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// 2. 获取版本信息
    static func getVersion(session: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔐 [BSPHP] 获取版本信息...")
        
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.version.rawValue
        params["BSphpSeSsL"] = session
        params["date"] = getCurrentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        params["appsafecode"] = getCurrentTimestamp()
        
        request(params) { result in
            switch result {
            case .success(let json):
                let version = json["response"]["data"].stringValue
                print("✅ [BSPHP] 版本信息: \(version)")
                completion(.success(version))
                
            case .failure(let error):
                print("❌ [BSPHP] 获取版本失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// 3. 卡密验证
    static func verifyCard(
        session: String,
        cardNumber: String,
        cardPassword: String = "",
        completion: @escaping (Result<LicenseInfo, Error>) -> Void
    ) {
        print("🔐 [BSPHP] 验证卡密...")
        print("   - 卡号: \(cardNumber)")
        
        let deviceKey = DeviceIdentifier.getDeviceKey()
        let onlineMark = DeviceIdentifier.getOnlineMark()
        
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.loginCard.rawValue
        params["BSphpSeSsL"] = session
        params["date"] = getCurrentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        params["appsafecode"] = getCurrentTimestamp()
        params["key"] = deviceKey
        params["maxoror"] = onlineMark
        params["icid"] = cardNumber
        params["icpwd"] = cardPassword
        
        request(params) { result in
            switch result {
            case .success(let json):
                // 解析响应
                let data = json["response"]["data"].stringValue
                let parts = data.components(separatedBy: "|")
                
                print("📡 [BSPHP] 响应数据: \(data)")
                
                // 检查返回格式
                // 成功: "01|1081|设备ID|验证数据|过期时间|||||"
                // 失败: "03|错误码|错误信息|||||"
                
                if parts.count >= 5 && parts[0] == "01" && parts[1] == "1081" {
                    // 验证成功
                    let license = LicenseInfo(
                        cardNumber: cardNumber,
                        deviceKey: parts[2],
                        verifyData: parts[3],
                        expireDate: parts[4],
                        verifiedAt: Date()
                    )
                    
                    print("✅ [BSPHP] 验证成功")
                    print("   - 设备: \(parts[2])")
                    print("   - 过期: \(parts[4])")
                    
                    completion(.success(license))
                } else {
                    // 验证失败 - 翻译错误码为用户友好的提示
                    let errorCode = parts.count >= 2 ? parts[1] : "未知"
                    let serverMessage = parts.count >= 3 ? parts[2] : data

                    print("❌ [BSPHP] 验证失败: \(serverMessage) (错误码: \(errorCode))")

                    // 根据错误码提供用户友好的提示
                    let userMessage = getUserFriendlyErrorMessage(errorCode: errorCode, serverMessage: serverMessage)

                    let error = NSError(
                        domain: "BSPHP",
                        code: Int(errorCode) ?? -1,
                        userInfo: [NSLocalizedDescriptionKey: userMessage]
                    )
                    completion(.failure(error))
                }
                
            case .failure(let error):
                print("❌ [BSPHP] 请求失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// 4. 获取公告
    static func getAnnouncement(session: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔐 [BSPHP] 获取公告...")
        
        var params: [String: Any] = [:]
        params["api"] = BSPHPApi.announcement.rawValue
        params["BSphpSeSsL"] = session
        params["date"] = getCurrentTimestamp()
        params["md5"] = appMD5
        params["mutualkey"] = mutualKey
        params["appsafecode"] = getCurrentTimestamp()
        
        request(params) { result in
            switch result {
            case .success(let json):
                let announcement = json["response"]["data"].stringValue
                print("✅ [BSPHP] 公告: \(announcement)")
                completion(.success(announcement))
                
            case .failure(let error):
                print("❌ [BSPHP] 获取公告失败: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - 辅助方法

    /// 将服务器错误码翻译为用户友好的提示
    private static func getUserFriendlyErrorMessage(errorCode: String, serverMessage: String) -> String {
        // 常见错误码映射
        let errorMap: [String: String] = [
            "1001": "卡密不存在，请检查是否输入正确",
            "1002": "卡密已过期，请续费或购买新卡密",
            "1003": "卡密已被封禁，请联系客服",
            "1004": "设备数量已达上限，请先解绑其他设备",
            "1005": "设备未授权，请先在其他设备上解绑",
            "1006": "卡密格式错误，请检查输入",
            "1007": "网络连接超时，请检查网络后重试",
            "1008": "服务器繁忙，请稍后重试",
            "1009": "参数错误，请重新输入",
            "1010": "签名验证失败，请重新安装应用"
        ]

        // 如果有映射的友好提示，使用映射
        if let friendlyMessage = errorMap[errorCode] {
            return friendlyMessage
        }

        // 检查服务器消息是否包含常见关键词
        let lowerMessage = serverMessage.lowercased()
        if lowerMessage.contains("不存在") || lowerMessage.contains("invalid") {
            return "卡密不存在，请检查是否输入正确"
        } else if lowerMessage.contains("过期") || lowerMessage.contains("expired") {
            return "卡密已过期，请续费或购买新卡密"
        } else if lowerMessage.contains("封禁") || lowerMessage.contains("banned") {
            return "卡密已被封禁，请联系客服"
        } else if lowerMessage.contains("设备") || lowerMessage.contains("device") {
            return "设备验证失败，请联系客服处理"
        } else if lowerMessage.contains("网络") || lowerMessage.contains("network") {
            return "网络连接失败，请检查网络后重试"
        }

        // 如果都没匹配，返回通用提示
        return "验证失败，请检查卡密是否正确\n或联系客服获取帮助"
    }

    // MARK: - 网络请求
    
    private static func request(
        _ params: [String: Any],
        completion: @escaping (Result<SimpleJSON, Error>) -> Void
    ) {
        // 1. 加密参数
        guard let encryptedParams = encryptParams(params) else {
            let error = NSError(domain: "BSPHP", code: -1, userInfo: [NSLocalizedDescriptionKey: "参数加密失败"])
            completion(.failure(error))
            return
        }
        
        print("🌐 [BSPHP] 发送请求: \(params["api"] ?? "")")
        
        // 2. 构建请求
        var request = URLRequest(url: URL(string: serverURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 构建 body
        let bodyString = encryptedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        // 3. 发送请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [BSPHP] 网络错误: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "BSPHP", code: -1, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])
                completion(.failure(error))
                return
            }
            
            // 4. 解密响应
            guard let json = decryptResponse(data, originalParams: params) else {
                let error = NSError(domain: "BSPHP", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应解密失败或签名验证失败"])
                completion(.failure(error))
                return
            }
            
            print("✅ [BSPHP] 请求成功")
            completion(.success(json))
            
        }.resume()
    }
    
    // MARK: - 测试方法（公开用于调试）
    
    static func testEncryptParams(_ params: [String: Any]) -> [String: Any]? {
        return encryptParams(params)
    }
    
    // MARK: - 加密参数
    
    private static func encryptParams(_ params: [String: Any]) -> [String: Any]? {
        print("\n" + String(repeating: "=", count: 60))
        print("📤 [BSPHP] 开始加密参数")
        print(String(repeating: "=", count: 60))
        
        // 1. 字典 → URL 字符串（按 key 排序）
        let paramString = formatDictToURLString(params)
        
        print("1️⃣ 原始参数字符串:")
        print("   内容: \(paramString)")
        print("   长度: \(paramString.count) 字符")
        
        // 2. 加密密码 → MD5
        let keyMD5 = encryptPassword.md5()
        print("\n2️⃣ 密钥MD5: \(keyMD5)")
        
        // 3. DES3 加密 (⚠️ IV必须与后台配置完全一致)
        print("\n3️⃣ DES3 加密中...")
        guard let encrypted = paramString.des3Crypt(operation: CCOperation(kCCEncrypt), key: keyMD5, iv: "bsphp666") else {
            print("❌ [BSPHP] DES3 加密失败")
            return nil
        }
        
        print("\n4️⃣ 加密结果:")
        print("   前80字符: \(encrypted.prefix(80))...")
        print("   总长度: \(encrypted.count) 字符")

        // 保存完整Base64到文件用于调试
        if let data = encrypted.data(using: .utf8) {
            let debugPath = "/tmp/bsphp_encrypted_base64.txt"
            try? data.write(to: URL(fileURLWithPath: debugPath))
            print("   ✅ 完整Base64已保存到: \(debugPath)")
        }

        // 检查是否有尾部空白字符
        print("   最后10字符(hex): \(encrypted.suffix(10).data(using: .utf8)?.map { String(format: "%02x", $0) }.joined(separator: " ") ?? "nil")")
        let hasNewline = encrypted.hasSuffix("\n")
        let hasCRLF = encrypted.hasSuffix("\r\n")
        print("   是否以换行符结尾: LF=\(hasNewline), CRLF=\(hasCRLF)")

        // 检查是否有尾部空白字符
        let encryptedTrimmed = encrypted.trimmingCharacters(in: .whitespacesAndNewlines)
        print("   修剪后长度: \(encryptedTrimmed.count)")

        // 4. 生成签名 (使用原始Base64,无换行符)
        // 🎯 根据后台调试报告: 签名组合 = 578 + 无换行符Base64 + 349
        let signString = inputSignKey.replacingOccurrences(of: "[KEY]", with: encrypted)
        let signature = signString.md5()
        print("\n4️⃣ 签名:")
        print("   inputSignKey长度: \(inputSignKey.count)")
        print("   encrypted长度: \(encrypted.count)")
        print("   签名字符串长度: \(signString.count) (预期: \(inputSignKey.count - 5 + encrypted.count))")
        print("   MD5签名: \(signature)")
        print("   🎯 后台期望: 578 + 无换行符Base64 + 349")

        // 5. URL编码 (签名计算完成后再进行URL编码)
        // 🎯 关键修复: Base64中的+号必须编码为%2B,否则后台会错误地解码为空格
        // application/x-www-form-urlencoded 会把 + 解码为空格
        // 但.urlQueryAllowed不会编码+号,所以需要手动替换
        guard let urlEncodedTemp = encrypted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ [BSPHP] URL编码失败")
            return nil
        }

        let urlEncoded = urlEncodedTemp.replacingOccurrences(of: "+", with: "%2B")

        let plusCount = encrypted.components(separatedBy: "+").count - 1
        print("\n5️⃣ URL编码:")
        print("   编码前长度: \(encrypted.count)")
        print("   编码后长度: \(urlEncoded.count)")
        print("   +号数量: \(plusCount) → 编码后应增加: \(plusCount * 2)字符")
        print("   前80字符: \(urlEncoded.prefix(80))...")
        
        return [
            "json": "ok",
            "sgin": signature,
            "parameter": urlEncoded
        ]
    }
    
    // MARK: - 解密响应
    
    private static func decryptResponse(_ data: Data, originalParams: [String: Any]) -> SimpleJSON? {
        // 1. Data → String
        guard let encryptedString = String(data: data, encoding: .utf8) else {
            print("❌ [BSPHP] 无法解析响应数据")
            return nil
        }
        
        print("📥 [BSPHP] 解密响应:")
        print("   加密响应: \(encryptedString.prefix(50))...(共\(encryptedString.count)字符)")
        
        // 2. 加密密码 → MD5
        let keyMD5 = encryptPassword.md5()
        print("   密钥MD5: \(keyMD5)")
        
        // 3. DES3 解密 (⚠️ IV必须与后台配置完全一致)
        guard let decrypted = encryptedString.des3Crypt(operation: CCOperation(kCCDecrypt), key: keyMD5, iv: "bsphp666") else {
            print("❌ [BSPHP] DES3 解密失败")
            print("   - 可能原因：密钥不对或数据损坏")
            return nil
        }
        
        print("   解密成功: \(decrypted.prefix(100))...")

        
        // 4. 解析 JSON
        guard let jsonData = decrypted.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("❌ [BSPHP] JSON 解析失败")
            return nil
        }
        
        let json = SimpleJSON(jsonObject)
        
        // 5. 验证签名
        guard let response = json["response"].dictionary else {
            print("❌ [BSPHP] 响应格式错误")
            return nil
        }
        
        let data = response["data"]?.stringValue ?? ""
        let date = response["date"]?.stringValue ?? ""
        let unix = response["unix"]?.stringValue ?? ""
        let microtime = response["microtime"]?.stringValue ?? ""
        let appsafecode = response["appsafecode"]?.stringValue ?? ""
        let receivedSign = response["sgin"]?.stringValue ?? ""
        
        let signString = "\(data)\(date)\(unix)\(microtime)\(appsafecode)"
        let fullString = outputSignKey.replacingOccurrences(of: "[KEY]", with: signString)
        let calculatedSign = fullString.md5()
        
        if calculatedSign == receivedSign {
            print("✅ [BSPHP] 签名验证通过")
            
            // 6. 验证防劫持码
            if let sentSafecode = originalParams["appsafecode"] as? String {
                if appsafecode != sentSafecode {
                    print("⚠️ [BSPHP] 防劫持码不匹配！可能被劫持")
                    return nil
                }
                print("✅ [BSPHP] 防劫持验证通过")
            }
            
            return json
        } else {
            print("❌ [BSPHP] 签名验证失败")
            print("   - 计算签名: \(calculatedSign)")
            print("   - 接收签名: \(receivedSign)")
            return nil
        }
    }
    
    // MARK: - 完整验证流程
    
    /// 完整的卡密验证流程（自动处理 Session 和版本检查）
    static func fullVerify(
        cardNumber: String,
        cardPassword: String = "",
        completion: @escaping (Result<LicenseInfo, Error>) -> Void
    ) {
        print("\n" + String(repeating: "=", count: 60))
        print("🔐 [BSPHP] 开始完整验证流程")
        print(String(repeating: "=", count: 60))
        
        // 步骤1: 获取 Session
        getBSphpSeSsL { result in
            switch result {
            case .success(let session):
                // 步骤2: 获取版本信息
                getVersion(session: session) { result in
                    switch result {
                    case .success(let versionInfo):
                        let parts = versionInfo.components(separatedBy: "|")
                        let serverVersion = parts.first ?? ""
                        
                        print("📌 [BSPHP] 版本检查:")
                        print("   - 客户端版本: \(appVersion)")
                        print("   - 服务器版本: \(serverVersion)")
                        
                        if serverVersion == appVersion {
                            // 步骤3: 卡密验证
                            verifyCard(session: session, cardNumber: cardNumber, cardPassword: cardPassword, completion: completion)
                        } else {
                            let error = NSError(domain: "BSPHP", code: -2, userInfo: [NSLocalizedDescriptionKey: "版本不匹配，请更新应用"])
                            completion(.failure(error))
                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - 简单的 JSON 解析器（替代 SwiftyJSON）

struct SimpleJSON {
    private let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    subscript(key: String) -> SimpleJSON {
        if let dict = value as? [String: Any],
           let v = dict[key] {
            return SimpleJSON(v)
        }
        return SimpleJSON(NSNull())
    }
    
    var stringValue: String {
        if let str = value as? String {
            return str
        }
        if let num = value as? NSNumber {
            return num.stringValue
        }
        return ""
    }
    
    var dictionary: [String: SimpleJSON]? {
        if let dict = value as? [String: Any] {
            return dict.mapValues { SimpleJSON($0) }
        }
        return nil
    }
}
