import Foundation
import Photos
import AVFoundation

/**
 * 功能描述: 视频服务 - 处理相册相关操作
 */
class VideoService {
    
    /**
     * 功能描述: 请求相册访问权限
     * Args:
     *     completion: 权限结果回调
     */
    static func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            print("✅ [VideoService] 相册权限已授予")
            completion(true)
        case .notDetermined:
            print("❓ [VideoService] 请求相册权限...")
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    let granted = (newStatus == .authorized || newStatus == .limited)
                    print(granted ? "✅ [VideoService] 用户授予权限" : "❌ [VideoService] 用户拒绝权限")
                    completion(granted)
                }
            }
        default:
            print("❌ [VideoService] 相册权限被拒绝或受限")
            completion(false)
        }
    }
    
    /**
     * 功能描述: 从相册导出视频到临时目录
     * Args:
     *     assetID: PHAsset的localIdentifier
     *     progress: 导出进度回调 (0.0 - 1.0)
     * Returns:
     *     Result<(String, String), Error> - (临时路径, 文件名)
     */
    static func exportVideoFromPhotos(
        assetID: String,
        progress: ((Double) -> Void)? = nil
    ) -> Result<(String, String), Error> {
        
        print("📤 [VideoService] 开始导出视频，assetID: \(assetID.prefix(20))...")
        
        // 检查是否是文件路径（以 file:// 开头）
        if assetID.hasPrefix("file://") {
            let filePath = String(assetID.dropFirst(7)) // 去掉 "file://" 前缀
            return exportVideoFromFile(filePath: filePath)
        }
        
        // 原有的相册逻辑
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        )
        
        guard let asset = fetchResult.firstObject else {
            print("❌ [VideoService] 无法找到PHAsset")
            return .failure(VideoError.assetNotFound)
        }
        
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        // 进度回调
        options.progressHandler = { progressValue, _, _, _ in
            DispatchQueue.main.async {
                progress?(progressValue)
            }
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(String, String), Error>?
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            defer { semaphore.signal() }
            
            guard let urlAsset = avAsset as? AVURLAsset else {
                print("❌ [VideoService] 无法获取AVURLAsset")
                result = .failure(VideoError.exportFailed("无法获取视频资源"))
                return
            }
            
            let sourceURL = urlAsset.url
            let fileName = sourceURL.lastPathComponent
            let tempPath = NSTemporaryDirectory() + fileName
            
            print("📝 [VideoService] 源文件: \(sourceURL.path)")
            print("📝 [VideoService] 文件名: \(fileName)")
            print("📝 [VideoService] 目标路径: \(tempPath)")
            
            do {
                // 如果已存在则删除
                if FileManager.default.fileExists(atPath: tempPath) {
                    try FileManager.default.removeItem(atPath: tempPath)
                    print("✓ [VideoService] 已删除旧文件")
                }
                
                // 复制到临时目录 (保持原文件名!)
                try FileManager.default.copyItem(atPath: sourceURL.path, toPath: tempPath)
                
                print("✓ [VideoService] 导出成功: \(fileName)")
                result = .success((tempPath, fileName))
                
            } catch {
                print("❌ [VideoService] 导出失败: \(error.localizedDescription)")
                result = .failure(error)
            }
        }
        
        semaphore.wait()
        
        guard let finalResult = result else {
            return .failure(VideoError.exportFailed("未知错误"))
        }
        
        return finalResult
    }
    
    /**
     * 功能描述: 从文件路径导出视频
     * Args:
     *     filePath: 文件完整路径
     * Returns:
     *     (临时文件路径, 文件名) 或 错误
     */
    private static func exportVideoFromFile(filePath: String) -> Result<(String, String), Error> {
        print("📁 [VideoService] 从文件导出: \(filePath)")
        print("   - 当前线程: \(Thread.current)")
        print("   - 是否主线程: \(Thread.isMainThread)")
        
        // 验证文件存在
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ [VideoService] 文件不存在: \(filePath)")
            return .failure(VideoError.exportFailed("文件不存在"))
        }
        
        let fileName = (filePath as NSString).lastPathComponent
        let tempDir = NSTemporaryDirectory()
        let tempFileName = "video_\(Date().timeIntervalSince1970)_\(fileName)"
        let tempPath = (tempDir as NSString).appendingPathComponent(tempFileName)
        
        do {
            // 复制文件到临时目录
            try FileManager.default.copyItem(atPath: filePath, toPath: tempPath)
            
            print("✅ [VideoService] 文件复制成功")
            print("   - 源文件: \(fileName)")
            print("   - 临时文件: \(tempPath)")
            
            return .success((tempPath, fileName))
            
        } catch {
            print("❌ [VideoService] 文件复制失败: \(error)")
            return .failure(error)
        }
    }
    
    /**
     * 功能描述: 获取视频资源信息
     * Args:
     *     assetID: PHAsset的localIdentifier
     * Returns:
     *     SavedVideoInfo?
     */
    static func getVideoInfo(assetID: String) -> SavedVideoInfo? {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        )
        
        guard let asset = fetchResult.firstObject else {
            return nil
        }
        
        // 获取文件名
        let resources = PHAssetResource.assetResources(for: asset)
        let fileName = resources.first?.originalFilename ?? "video.mp4"
        
        // 获取文件大小（估算）
        var fileSize: Int64 = 0
        if let resource = resources.first,
           let unsignedSize = resource.value(forKey: "fileSize") as? Int64 {
            fileSize = unsignedSize
        }
        
        // 获取时长
        let duration = asset.duration
        
        return SavedVideoInfo(
            assetIdentifier: assetID,
            fileName: fileName,
            fileSize: fileSize,
            duration: duration,
            savedDate: Date()
        )
    }
}

/**
 * 功能描述: 视频相关错误定义
 */
enum VideoError: LocalizedError {
    case assetNotFound
    case exportFailed(String)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "无法找到视频资源"
        case .exportFailed(let reason):
            return "导出失败: \(reason)"
        case .permissionDenied:
            return "相册访问权限被拒绝"
        }
    }
}
