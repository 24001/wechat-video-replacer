import Foundation

/**
 * 功能描述: 微信服务 - 处理微信容器相关操作
 * 实现方式: 使用 container-manager entitlement 直接访问，无需 root 权限
 */
class WechatService {

    /**
     * 功能描述: 通过 Bundle ID 定位微信应用容器
     * 说明: 使用 container-manager entitlement 直接访问
     * Returns:
     *     微信容器完整路径，未找到返回 nil
     */
    static func findWechatContainer() -> String? {
        print("🔍 [WechatService] 开始查找微信容器...")
        print("🔍 [WechatService] 当前线程: \(Thread.current)")
        
        let fm = FileManager.default
        let basePath = WechatConstants.containerBasePath
        
        print("📂 [WechatService] 扫描路径: \(basePath)")
        
        // 检查路径是否存在
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: basePath, isDirectory: &isDir)
        print("📂 [WechatService] 路径存在: \(exists), 是目录: \(isDir.boolValue)")
        
        guard let containers = try? fm.contentsOfDirectory(atPath: basePath) else {
            print("❌ [WechatService] 无法读取容器目录")
            
            // 尝试获取具体错误
            do {
                let _ = try fm.contentsOfDirectory(atPath: basePath)
            } catch {
                print("❌ [WechatService] 错误详情: \(error)")
            }
            
            return nil
        }
        
        print("✓ [WechatService] 成功读取 \(containers.count) 个容器")
        
        for uuid in containers {
            let metadataPath = "\(basePath)\(uuid)/\(WechatConstants.metadataFile)"
            
            if let metadata = NSDictionary(contentsOfFile: metadataPath),
               let bundleID = metadata[WechatConstants.metadataKeyBundleID] as? String {
                
                if bundleID.contains("tencent") {
                    print("🔍 [WechatService] 发现腾讯应用: \(bundleID)")
                }
                
                if bundleID == WechatConstants.bundleID {
                    let containerPath = "\(basePath)\(uuid)"
                    print("✅ [WechatService] 找到微信容器: \(containerPath)")
                    return containerPath
                }
            }
        }
        
        print("❌ [WechatService] 未找到微信容器")
        return nil
    }

    /**
     * 功能描述: 获取微信 tmp 目录路径
     * Returns:
     *     微信 tmp 目录完整路径，失败返回 nil
     */
    static func getWechatTmpPath() -> String? {
        guard let containerPath = findWechatContainer() else {
            return nil
        }
        return "\(containerPath)/tmp"
    }

    /**
     * 功能描述: 在微信 tmp 目录查找最新的 LocalShortVideo 文件
     * Args:
     *     tmpPath: 微信 tmp 目录路径
     * Returns:
     *     最新视频文件名，未找到返回 nil
     */
    static func findLatestVideoCache(in tmpPath: String) -> String? {
        print("🔍 [WechatService] 查找最新视频缓存，路径: \(tmpPath)")
        
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(atPath: tmpPath) else {
            print("❌ [WechatService] 无法读取 tmp 目录")
            return nil
        }

        // 筛选 LocalShortVideo 开头的文件
        let videoFiles = files.filter { $0.hasPrefix(WechatConstants.videoCachePrefix) }
        
        print("✓ [WechatService] 找到 \(videoFiles.count) 个 LocalShortVideo 文件")

        guard !videoFiles.isEmpty else {
            print("❌ [WechatService] 未找到视频缓存文件")
            return nil
        }

        // 按创建时间降序排序
        let sortedFiles = videoFiles.sorted { file1, file2 in
            let path1 = "\(tmpPath)/\(file1)"
            let path2 = "\(tmpPath)/\(file2)"

            let attr1 = try? fm.attributesOfItem(atPath: path1)
            let attr2 = try? fm.attributesOfItem(atPath: path2)

            let date1 = attr1?[.creationDate] as? Date ?? Date.distantPast
            let date2 = attr2?[.creationDate] as? Date ?? Date.distantPast

            return date1 > date2  // 最新的在前
        }

        let latestFile = sortedFiles.first!
        print("✅ [WechatService] 找到最新缓存: \(latestFile)")
        return latestFile
    }

    /**
     * 功能描述: 检查微信是否已安装
     * Returns:
     *     true 表示已安装，false 表示未安装
     */
    static func isWechatInstalled() -> Bool {
        return findWechatContainer() != nil
    }
    
    /**
     * 功能描述: 诊断容器访问（用于调试）
     * Returns:
     *     诊断信息字符串数组
     */
    static func diagnoseContainerAccess() -> [String] {
        var results: [String] = []

        results.append("📂 容器访问诊断报告")
        results.append("=" + String(repeating: "=", count: 50))
        results.append("")
        
        results.append("🔑 访问方式: 直接访问（container-manager entitlement）")
        results.append("")
        
        let fm = FileManager.default
        let basePath = WechatConstants.containerBasePath
        
        results.append("📂 扫描路径: \(basePath)")
        results.append("")
        
        // 检查目录是否可访问
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: basePath, isDirectory: &isDir)
        
        results.append("🔍 步骤1: 检查基础路径")
        results.append("   存在: \(exists)")
        results.append("   是目录: \(isDir.boolValue)")
        results.append("")
        
        if !exists {
            results.append("❌ 路径不存在！")
            return results
        }
        
        results.append("🔍 步骤2: 尝试读取容器列表")
        
        do {
            let containers = try fm.contentsOfDirectory(atPath: basePath)
            results.append("✅ 成功读取 \(containers.count) 个容器")
            results.append("")
            
            results.append("🔍 步骤3: 扫描容器查找微信")
            results.append("-" + String(repeating: "-", count: 50))
            
            var wechatFound = false
            var tencentApps: [String] = []
            
            for uuid in containers {
                let metadataPath = "\(basePath)\(uuid)/\(WechatConstants.metadataFile)"
                
                if let metadata = NSDictionary(contentsOfFile: metadataPath),
                   let bundleID = metadata[WechatConstants.metadataKeyBundleID] as? String {
                    
                    if bundleID.contains("tencent") {
                        tencentApps.append(bundleID)
                        
                        if bundleID == WechatConstants.bundleID {
                            wechatFound = true
                            let fullPath = "\(basePath)\(uuid)"
                            
                            results.append("🎯 找到微信！")
                            results.append("   Bundle ID: \(bundleID)")
                            results.append("   UUID: \(uuid)")
                            results.append("   容器路径: \(fullPath)")
                            results.append("")
                            
                            // 检查关键目录
                            let documentsPath = "\(fullPath)/Documents"
                            let libraryPath = "\(fullPath)/Library"
                            let tmpPath = "\(fullPath)/tmp"
                            
                            if fm.fileExists(atPath: documentsPath) {
                                results.append("   📁 Documents: ✅ 存在")
                                if let docs = try? fm.contentsOfDirectory(atPath: documentsPath) {
                                    results.append("      包含 \(docs.count) 个项目")
                                }
                            } else {
                                results.append("   📁 Documents: ❌ 不存在")
                            }
                            
                            if fm.fileExists(atPath: libraryPath) {
                                results.append("   📁 Library: ✅ 存在")
                            } else {
                                results.append("   📁 Library: ❌ 不存在")
                            }
                            
                            if fm.fileExists(atPath: tmpPath) {
                                results.append("   📁 tmp: ✅ 存在")
                                if let tmpFiles = try? fm.contentsOfDirectory(atPath: tmpPath) {
                                    let videoFiles = tmpFiles.filter { $0.hasPrefix("LocalShortVideo") }
                                    results.append("      包含 \(tmpFiles.count) 个文件")
                                    results.append("      LocalShortVideo: \(videoFiles.count) 个")
                                }
                            } else {
                                results.append("   📁 tmp: ❌ 不存在")
                            }
                            
                            results.append("")
                        } else {
                            results.append("⚠️  \(bundleID)")
                            results.append("   UUID: \(uuid.prefix(13))...")
                        }
                    }
                }
            }
            
            results.append("-" + String(repeating: "-", count: 50))
            results.append("扫描统计: \(containers.count) 个容器")
            results.append("腾讯应用: \(tencentApps.count) 个")
            results.append("")
            
            if wechatFound {
                results.append("✅ 找到微信！直接访问成功！")
                results.append("")
                results.append("💡 这证明:")
                results.append("• container-manager entitlement 生效")
                results.append("• 可以直接操作文件")
                results.append("• 可以执行完整替换流程")
            } else {
                results.append("❌ 未找到微信")
                results.append("")
                
                if !tencentApps.isEmpty {
                    results.append("发现的腾讯应用:")
                    for app in tencentApps {
                        results.append("• \(app)")
                    }
                } else {
                    results.append("未发现任何腾讯应用")
                    results.append("")
                    results.append("请确认:")
                    results.append("• 微信已安装")
                    results.append("• 微信已打开过至少一次")
                }
            }
            
        } catch {
            results.append("❌ 读取失败: \(error.localizedDescription)")
            results.append("")
            results.append("可能原因:")
            results.append("• entitlements 未生效")
            results.append("• 需要通过 TrollStore 安装")
            results.append("• iOS 版本不支持此 entitlement")
        }
        
        return results
    }
}
