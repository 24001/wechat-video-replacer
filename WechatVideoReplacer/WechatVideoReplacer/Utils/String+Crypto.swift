//
//  String+Crypto.swift
//  WechatVideoReplacer
//
//  BSPHP 加密扩展 - MD5 和 DES3
//

import Foundation
import CommonCrypto

// MARK: - MD5 扩展

extension String {
    
    /// MD5 加密（32位小写）
    func md5() -> String {
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: Int(CC_MD5_DIGEST_LENGTH))
        
        CC_MD5(str!, strLen, result)
        
        let hash = NSMutableString()
        
        for i in 0 ..< Int(CC_MD5_DIGEST_LENGTH) {
            hash.appendFormat("%02x", result[i])
        }
        
        result.deallocate()
        
        return String(format: hash as String)
    }
}

// MARK: - DES3 扩展

extension String {
    
    /// DES3 加密/解密
    /// - Parameters:
    ///   - operation: kCCEncrypt (加密) 或 kCCDecrypt (解密)
    ///   - key: 密钥（通常是 MD5 后的字符串）
    ///   - iv: 初始化向量
    /// - Returns: 加密/解密后的字符串
    func des3Crypt(operation: CCOperation, key: String, iv: String) -> String? {
        
        guard let keyData = key.data(using: .utf8) else {
            print("❌ [Crypto] 密钥转换失败")
            return nil
        }
        
        var cryptData: Data?
        
        if operation == kCCEncrypt {
            cryptData = self.data(using: .utf8)
        } else {
            cryptData = Data(base64Encoded: self, options: .ignoreUnknownCharacters)
        }
        
        guard let cryptData = cryptData else {
            print("❌ [Crypto] 数据转换失败")
            return nil
        }
        
        let algorithm: CCAlgorithm = CCAlgorithm(kCCAlgorithm3DES)
        let option: CCOptions = CCOptions(kCCOptionPKCS7Padding)

        // ⚠️ 完全对齐官方SDK：直接使用完整keyData，不手动截断
        // CCCrypt会根据keyLength自动取前24字节
        let keyBytes = [UInt8](keyData)
        let keyLength = size_t(kCCKeySize3DES)

        print("🔑 [Crypto] 密钥字节数: \(keyBytes.count), 使用长度: \(keyLength)")
        
        let dataIn = [UInt8](cryptData)
        let dataInLength = size_t(cryptData.count)
        
        if operation == kCCEncrypt {
            print("🔐 [Crypto] 加密输入长度: \(dataInLength)")
        } else {
            print("🔓 [Crypto] 解密输入长度: \(dataInLength)")
        }
        
        let dataOutAvailable = size_t(dataInLength + kCCBlockSize3DES)
        let dataOut = UnsafeMutablePointer<UInt8>.allocate(capacity: dataOutAvailable)
        var dataOutMoved = 0
        
        let ivBytes = [UInt8](iv.data(using: .utf8)!)
        print("🔑 [Crypto] IV: \(iv) (长度: \(ivBytes.count)字节)")
        
        let cryptStatus = CCCrypt(
            operation,
            algorithm,
            option,
            keyBytes,
            keyLength,
            ivBytes,
            dataIn,
            dataInLength,
            dataOut,
            dataOutAvailable,
            &dataOutMoved
        )
        
        var data: Data?
        
        if CCStatus(cryptStatus) == CCStatus(kCCSuccess) {
            data = Data(bytes: dataOut, count: dataOutMoved)
            if operation == kCCEncrypt {
                print("✅ [Crypto] 加密成功，输出长度: \(dataOutMoved)")
            } else {
                print("✅ [Crypto] 解密成功，输出长度: \(dataOutMoved)")
            }
        } else {
            print("❌ [Crypto] 操作失败，状态码: \(cryptStatus)")
        }
        
        dataOut.deallocate()
        
        guard let resultData = data else {
            print("❌ [Crypto] 结果数据为空")
            return nil
        }
        
        if operation == kCCEncrypt {
            // 🎯 关键修复: 使用无换行符的Base64编码!
            // 后台计算签名时使用的是无换行符的Base64
            let base64Data = resultData.base64EncodedData(options: [])
            let result = String(data: base64Data, encoding: .utf8)
            
            // 调试：检查换行符类型
            let hasCRLF = result?.contains("\r\n") ?? false
            let hasLF = result?.contains("\n") ?? false
            print("🔍 [Crypto] Base64换行符: CRLF=\(hasCRLF), LF=\(hasLF)")
            
            // 🔥 关键修复: 强制清理所有换行符，确保真机和模拟器行为一致
            // base64EncodedData(options: []) 在不同iOS版本/编译模式下可能有差异
            let cleanResult = result?.replacingOccurrences(of: "\r", with: "")
                                    .replacingOccurrences(of: "\n", with: "")
                                    .trimmingCharacters(in: .whitespaces)

            print("📤 [Crypto] Base64输出(清理后): \(cleanResult?.prefix(80) ?? "nil")... (共\(cleanResult?.count ?? 0)字符)")
            return cleanResult
        }
        
        // 🔍 调试：先查看原始字节
        let hexString = resultData.map { String(format: "%02x", $0) }.joined()
        print("🔍 [Crypto] 解密原始数据(hex): \(hexString.prefix(200))...")

        // 尝试多种编码方式
        var result = String(data: resultData, encoding: .utf8)
        if result == nil {
            print("⚠️ [Crypto] UTF-8解码失败，尝试ISO Latin 1...")
            result = String(data: resultData, encoding: .isoLatin1)
        }
        if result == nil {
            print("⚠️ [Crypto] ISO Latin 1解码失败，尝试ASCII...")
            result = String(data: resultData, encoding: .ascii)
        }

        print("📤 [Crypto] 解密输出: \(result?.prefix(100) ?? "nil")...")
        return result
    }
}

// MARK: - 工具函数

/// 获取当前时间字符串（BSPHP 格式）
func getCurrentTimestamp() -> String {
    let formatter = DateFormatter()
    // ⚠️ 官方SDK用的是：yyyy/MM/dd#HH:mm:ss（斜杠！）
    // 🔥 修复：使用 yyyy（日历年）而不是 YYYY（周年），避免跨年问题
    formatter.dateFormat = "yyyy/MM/dd#HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")  // 确保格式一致性
    formatter.timeZone = TimeZone.current  // 使用设备当前时区
    return formatter.string(from: Date())
}

/// 字典转 URL 参数字符串（按字母排序）
func formatDictToURLString(_ dict: [String: Any]) -> String {
    // ⚠️ 官方SDK使用字母排序，不是固定顺序！
    var tmp: [String] = []
    for (k, v) in dict.sorted(by: { $0.key < $1.key }) {
        tmp.append("\(k)=\(v)")
    }
    return tmp.joined(separator: "&")
}
