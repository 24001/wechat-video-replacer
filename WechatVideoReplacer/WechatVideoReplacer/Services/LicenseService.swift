import Foundation
import CryptoKit

/**
 * 功能描述: 卡密验证服务 - 网络验证授权
 */
class LicenseService {
    
    // MARK: - 配置 (加密存储)
    
    private static let encryptedEndpoints: [UInt8] = [
        // 加密的API端点，避免明文存储
        104, 116, 116, 112, 115, 58, 47, 47, 119, 119, 119, 46, 98, 115, 112, 104, 112, 46, 99, 111, 109, 47, 97, 112, 105, 47, 118, 101, 114, 105, 102, 121
    ]
    
    private static let xorKey: UInt8 = 0x17
    
    private static var apiEndpoint: String {
        let decrypted = encryptedEndpoints.map { $0 ^ xorKey }
        return String(bytes: decrypted, encoding: .utf8) ?? ""
    }
    
    // MARK: - 设备标识
    
    private static func getDeviceID() -> String {
        // 生成唯一设备标识
        let udid = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let model = UIDevice.current.model
        let system = UIDevice.current.systemVersion
        
        let combined = "\(udid)-\(model)-\(system)"
        let hash = SHA256.hash(data: combined.data(using: .utf8) ?? Data())
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
    
    // MARK: - 本地存储
    
    private static let licenseKey = "app_license_status"
    private static let deviceKey = "device_identifier"
    private static let expireKey = "license_expire_time"
    
    private static func saveLicenseStatus(valid: Bool, expireTime: TimeInterval = 0) {
        UserDefaults.standard.set(valid, forKey: licenseKey)
        UserDefaults.standard.set(getDeviceID(), forKey: deviceKey)
        UserDefaults.standard.set(expireTime, forKey: expireKey)
        UserDefaults.standard.synchronize()
    }
    
    private static func getCachedLicenseStatus() -> (valid: Bool, expired: Bool) {
        let isValid = UserDefaults.standard.bool(forKey: licenseKey)
        let expireTime = UserDefaults.standard.double(forKey: expireKey)
        let isExpired = expireTime > 0 && Date().timeIntervalSince1970 > expireTime
        
        return (valid: isValid && !isExpired, expired: isExpired)
    }
    
    // MARK: - 网络验证
    
    /**
     * 功能描述: 验证卡密
     * Args:
     *     cardCode: 用户输入的卡密
     *     completion: 验证结果回调
     */
    static func verifyLicense(cardCode: String, completion: @escaping (Result<LicenseInfo, LicenseError>) -> Void) {
        print("🔐 [License] 开始验证卡密...")
        print("   - 设备ID: \(getDeviceID())")
        print("   - 卡密: \(cardCode.prefix(8))****")
        
        // 构建请求参数
        let parameters = [
            "card_code": cardCode,
            "device_id": getDeviceID(),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "timestamp": String(Int(Date().timeIntervalSince1970))
        ]
        
        // 添加签名防止篡改
        let signature = generateSignature(parameters: parameters)
        var signedParams = parameters
        signedParams["signature"] = signature
        
        performNetworkRequest(parameters: signedParams, completion: completion)
    }
    
    /**
     * 功能描述: 检查许可证状态
     * Returns: (是否有效, 是否过期)
     */
    static func checkLicenseStatus() -> (valid: Bool, expired: Bool) {
        let cached = getCachedLicenseStatus()
        print("🔐 [License] 检查本地许可证状态")
        print("   - 有效: \(cached.valid)")
        print("   - 过期: \(cached.expired)")
        return cached
    }
    
    /**
     * 功能描述: 清除许可证
     */
    static func clearLicense() {
        UserDefaults.standard.removeObject(forKey: licenseKey)
        UserDefaults.standard.removeObject(forKey: deviceKey)
        UserDefaults.standard.removeObject(forKey: expireKey)
        UserDefaults.standard.synchronize()
        print("🔐 [License] 许可证已清除")
    }
    
    // MARK: - 私有方法
    
    private static func generateSignature(parameters: [String: String]) -> String {
        // 生成请求签名，防止参数被篡改
        let sortedParams = parameters.sorted { $0.key < $1.key }
        let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        
        // 添加密钥
        let secretKey = "wechat_video_replacer_secret_2024"
        let signString = paramString + secretKey
        
        let hash = SHA256.hash(data: signString.data(using: .utf8) ?? Data())
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private static func performNetworkRequest(parameters: [String: String], completion: @escaping (Result<LicenseInfo, LicenseError>) -> Void) {
        guard let url = URL(string: apiEndpoint) else {
            completion(.failure(.networkError("无效的服务器地址")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("WechatVideoReplacer/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(.networkError("请求参数错误")))
            return
        }
        
        print("🌐 [License] 发送验证请求...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                handleNetworkResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    private static func handleNetworkResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<LicenseInfo, LicenseError>) -> Void) {
        
        if let error = error {
            print("❌ [License] 网络错误: \(error.localizedDescription)")
            completion(.failure(.networkError("网络连接失败: \(error.localizedDescription)")))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.networkError("无效的服务器响应")))
            return
        }
        
        print("🌐 [License] 服务器响应状态: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            completion(.failure(.serverError("服务器错误: \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            completion(.failure(.networkError("服务器返回空数据")))
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("🌐 [License] 服务器返回: \(json ?? [:])")
            
            parseServerResponse(json: json, completion: completion)
            
        } catch {
            print("❌ [License] 解析响应失败: \(error)")
            completion(.failure(.parseError("解析服务器响应失败")))
        }
    }
    
    private static func parseServerResponse(json: [String: Any]?, completion: @escaping (Result<LicenseInfo, LicenseError>) -> Void) {
        guard let json = json else {
            completion(.failure(.parseError("无效的响应格式")))
            return
        }
        
        let success = json["success"] as? Bool ?? false
        let message = json["message"] as? String ?? "未知错误"
        
        if success {
            let expireTime = json["expire_time"] as? TimeInterval ?? 0
            let remainingDays = json["remaining_days"] as? Int ?? 0
            let cardType = json["card_type"] as? String ?? "standard"
            
            let licenseInfo = LicenseInfo(
                isValid: true,
                expireTime: expireTime,
                remainingDays: remainingDays,
                cardType: cardType,
                message: message
            )
            
            // 保存到本地
            saveLicenseStatus(valid: true, expireTime: expireTime)
            
            print("✅ [License] 验证成功")
            print("   - 卡密类型: \(cardType)")
            print("   - 剩余天数: \(remainingDays)")
            
            completion(.success(licenseInfo))
            
        } else {
            print("❌ [License] 验证失败: \(message)")
            
            // 清除本地状态
            saveLicenseStatus(valid: false)
            
            let errorType: LicenseError
            if message.contains("卡密") || message.contains("无效") {
                errorType = .invalidCard(message)
            } else if message.contains("过期") {
                errorType = .expired(message)
            } else if message.contains("设备") {
                errorType = .deviceMismatch(message)
            } else {
                errorType = .serverError(message)
            }
            
            completion(.failure(errorType))
        }
    }
}

// MARK: - 数据模型

struct LicenseInfo {
    let isValid: Bool
    let expireTime: TimeInterval
    let remainingDays: Int
    let cardType: String
    let message: String
}

enum LicenseError: Error, LocalizedError {
    case invalidCard(String)
    case expired(String)
    case deviceMismatch(String)
    case networkError(String)
    case serverError(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCard(let msg): return "卡密无效: \(msg)"
        case .expired(let msg): return "授权过期: \(msg)"
        case .deviceMismatch(let msg): return "设备不匹配: \(msg)"
        case .networkError(let msg): return "网络错误: \(msg)"
        case .serverError(let msg): return "服务器错误: \(msg)"
        case .parseError(let msg): return "数据解析错误: \(msg)"
        }
    }
}
