//
//  LicenseInfo.swift
//  WechatVideoReplacer
//
//  授权信息模型
//

import Foundation

/// 授权信息
struct LicenseInfo: Codable {
    let cardNumber: String          // 卡号
    let deviceKey: String           // 绑定的设备标识
    let verifyData: String          // 验证数据
    let expireDate: String          // 到期时间（格式: yyyy-MM-dd HH:mm:ss）
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
        
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    /// 剩余天数
    var remainingDays: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let expireDate = formatter.date(from: self.expireDate) else {
            return 0
        }
        
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expireDate).day ?? 0
        return max(0, days)
    }
}

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
            print("✅ [LicenseManager] 授权信息已保存")
            print("   - 卡号: \(license.cardNumber)")
            print("   - 到期: \(license.expireDate)")
        }
    }
    
    /// 加载授权信息
    func load() -> LicenseInfo? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("⚠️ [LicenseManager] 无授权信息")
            return nil
        }
        
        let decoder = JSONDecoder()
        let license = try? decoder.decode(LicenseInfo.self, from: data)
        
        if let license = license {
            print("✅ [LicenseManager] 已加载授权信息")
            print("   - 卡号: \(license.cardNumber)")
            print("   - 到期: \(license.expireDate)")
        }
        
        return license
    }
    
    /// 清除授权信息
    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.synchronize()
        print("🗑️ [LicenseManager] 授权信息已清除")
    }
    
    // MARK: - 验证状态
    
    /// 检查是否已授权且未过期
    func isValid() -> Bool {
        guard let license = load() else {
            print("❌ [LicenseManager] 未找到授权信息")
            return false
        }
        
        // 检查是否过期
        if license.isExpired {
            print("⚠️ [LicenseManager] 授权已过期")
            print("   - 过期时间: \(license.expireDate)")
            return false
        }
        
        print("✅ [LicenseManager] 授权有效")
        print("   - 剩余天数: \(license.remainingDays) 天")
        return true
    }
    
    /// 获取授权信息摘要
    func getSummary() -> String? {
        guard let license = load() else {
            return nil
        }
        
        return """
        卡号: \(license.cardNumber)
        到期: \(license.expireDateFormatted)
        剩余: \(license.remainingDays) 天
        设备: \(license.deviceKey.prefix(8))...
        """
    }
}
