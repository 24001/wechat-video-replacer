import Foundation

/**
 * 功能描述: 文件服务 - 处理文件操作
 */
class FileService {

    /**
     * 功能描述: 执行视频文件替换操作
     * Args:
     *     ourFileName: 我们上传的文件名 (如: IMG_1234.MOV)
     *     cacheFileName: 微信缓存文件名 (如: LocalShortVideo_xxx.mp4)
     *     tmpPath: 微信tmp目录路径
     * Returns:
     *     Result<Void, Error> - 成功或错误
     * 执行流程:
     *     1. 备份微信原始缓存文件
     *     2. 重命名我们的素材文件
     *     3. 出错时自动回滚
     */
    static func replaceVideo(ourFileName: String, cacheFileName: String, in tmpPath: String) -> Result<Void, Error> {
        let fm = FileManager.default

        let ourFilePath = "\(tmpPath)/\(ourFileName)"
        let cacheFilePath = "\(tmpPath)/\(cacheFileName)"
        let backupPath = "\(tmpPath)/backup_\(Date().timeIntervalSince1970).tmp"

        do {
            // 检查文件是否存在
            guard fm.fileExists(atPath: ourFilePath) else {
                throw NSError(domain: "FileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到上传的文件"])
            }

            guard fm.fileExists(atPath: cacheFilePath) else {
                throw NSError(domain: "FileService", code: 2, userInfo: [NSLocalizedDescriptionKey: "找不到微信缓存文件"])
            }

            // 备份微信原始缓存
            try fm.moveItem(atPath: cacheFilePath, toPath: backupPath)

            // 重命名我们的素材
            try fm.moveItem(atPath: ourFilePath, toPath: cacheFilePath)

            return .success(())

        } catch {
            // 回滚操作
            if fm.fileExists(atPath: backupPath) && !fm.fileExists(atPath: cacheFilePath) {
                try? fm.moveItem(atPath: backupPath, toPath: cacheFilePath)
            }

            return .failure(error)
        }
    }

    /**
     * 功能描述: 复制文件到目标路径
     * Args:
     *     sourcePath: 源文件路径
     *     destinationPath: 目标路径
     * Returns:
     *     Result<Void, Error> - 成功或错误
     */
    static func copyFile(from sourcePath: String, to destinationPath: String) -> Result<Void, Error> {
        print("📋 [FileService] 开始复制文件...")
        print("   - 当前线程: \(Thread.current)")
        print("   - 是否主线程: \(Thread.isMainThread)")
        print("   - 源文件: \(sourcePath)")
        print("   - 目标: \(destinationPath)")
        
        let fm = FileManager.default
        
        // 检查源文件
        let sourceExists = fm.fileExists(atPath: sourcePath)
        print("   - 源文件存在: \(sourceExists)")
        if sourceExists {
            let attrs = try? fm.attributesOfItem(atPath: sourcePath)
            let size = attrs?[.size] as? Int64 ?? 0
            print("   - 源文件大小: \(size) bytes")
        }

        do {
            // 检查目标目录
            let destinationDir = (destinationPath as NSString).deletingLastPathComponent
            var isDir: ObjCBool = false
            let dirExists = fm.fileExists(atPath: destinationDir, isDirectory: &isDir)
            print("   - 目标目录存在: \(dirExists), 是目录: \(isDir.boolValue)")
            
            // 如果目标文件已存在,先删除
            if fm.fileExists(atPath: destinationPath) {
                print("   - 目标文件已存在，先删除")
                try fm.removeItem(atPath: destinationPath)
            }

            // 复制文件
            print("   - 开始复制...")
            try fm.copyItem(atPath: sourcePath, toPath: destinationPath)
            
            // 验证复制结果
            let copied = fm.fileExists(atPath: destinationPath)
            print("   - 复制完成，目标文件存在: \(copied)")

            return .success(())

        } catch {
            print("❌ [FileService] 复制失败: \(error)")
            print("   - 错误类型: \(type(of: error))")
            print("   - 错误描述: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /**
     * 功能描述: 清理临时文件
     * Args:
     *     path: 要删除的文件路径
     */
    static func cleanupTempFile(at path: String) {
        let fm = FileManager.default

        if fm.fileExists(atPath: path) {
            try? fm.removeItem(atPath: path)
        }
    }

    /**
     * 功能描述: 获取文件大小
     * Args:
     *     path: 文件路径
     * Returns:
     *     文件大小(字节),失败返回0
     */
    static func getFileSize(at path: String) -> Int64 {
        let fm = FileManager.default

        guard let attributes = try? fm.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }

        return fileSize
    }
}
