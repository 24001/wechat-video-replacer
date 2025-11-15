//
//  DeviceIdentifier.swift
//  WechatVideoReplacer
//
//  设备标识生成器
//

import UIKit

/// 设备标识生成器
class DeviceIdentifier {
    
    /// 获取唯一设备标识（使用 IDFV）
    /// - Returns: 设备唯一标识符
    static func getDeviceKey() -> String {
        // 优先使用 IDFV (identifierForVendor)
        // 优点：无需用户授权，对同一开发者的所有应用相同
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }
        
        // 备用方案：生成随机 UUID 并持久化
        if let savedKey = UserDefaults.standard.string(forKey: "deviceKey") {
            return savedKey
        }
        
        let newKey = UUID().uuidString
        UserDefaults.standard.set(newKey, forKey: "deviceKey")
        UserDefaults.standard.synchronize()
        return newKey
    }
    
    /// 获取在线标记（用于多开控制）
    /// - Returns: 唯一的在线标记
    static func getOnlineMark() -> String {
        // 使用设备ID + 时间戳，确保每次启动都不同
        let deviceKey = getDeviceKey()
        let timestamp = Date().timeIntervalSince1970
        return "\(deviceKey)_\(Int64(timestamp))"
    }
    
    /// 获取设备信息摘要
    /// - Returns: 设备信息字符串
    static func getDeviceInfo() -> String {
        let device = UIDevice.current
        return """
        设备: \(device.model)
        系统: iOS \(device.systemVersion)
        标识: \(getDeviceKey().prefix(8))...
        """
    }
}
