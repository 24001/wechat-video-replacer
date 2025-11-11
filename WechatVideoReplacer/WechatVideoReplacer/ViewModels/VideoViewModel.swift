import Foundation
import Photos

/**
 * 功能描述: 视频替换 ViewModel - 核心业务逻辑
 */
class VideoViewModel {

    // MARK: - 属性

    /// 当前保存的视频信息
    private(set) var savedVideo: SavedVideoInfo?

    /// 状态更新回调
    var onStatusUpdate: ((String) -> Void)?

    /// 错误回调
    var onError: ((String) -> Void)?
    
    /// 微信容器路径缓存（解决 UIAlertController callback 权限问题）
    private var cachedWechatTmpPath: String?

    // MARK: - 初始化

    init() {
        loadSavedVideo()
    }

    // MARK: - 预检查
    
    /**
     * 功能描述: 预先获取并缓存微信容器路径
     * Returns: 是否成功获取路径
     * 说明: 必须在显示 UIAlertController 之前调用，避免权限失效
     */
    func prefetchWechatPath() -> Bool {
        print("🔍 [Prefetch] 预先获取微信容器路径...")
        guard let path = WechatService.getWechatTmpPath() else {
            print("❌ [Prefetch] 失败：找不到微信应用")
            cachedWechatTmpPath = nil
            return false
        }
        cachedWechatTmpPath = path
        print("✅ [Prefetch] 成功：路径已缓存")
        print("   - 路径: \(path)")
        return true
    }
    
    /**
     * 功能描述: 清除微信路径缓存
     */
    func clearWechatPathCache() {
        cachedWechatTmpPath = nil
        print("✅ 已清除微信路径缓存")
    }
    
    /**
     * 功能描述: 重新加载保存的素材
     */
    func reloadSavedVideo() {
        loadSavedVideo()
    }

    // MARK: - 持久化

    /**
     * 功能描述: 从 UserDefaults 加载已保存的视频信息
     */
    private func loadSavedVideo() {
        savedVideo = VideoStorageManager.shared.load()
    }

    /**
     * 功能描述: 保存视频信息
     * Args:
     *     video: 要保存的视频信息
     */
    private func saveVideo(_ video: SavedVideoInfo) {
        VideoStorageManager.shared.save(videoInfo: video)
        savedVideo = video
    }

    /**
     * 功能描述: 清除已保存的视频信息
     */
    func clearSavedVideo() {
        VideoStorageManager.shared.clear()
        savedVideo = nil
    }

    // MARK: - 视频选择

    /**
     * 功能描述: 保存用户选择的视频（从相册）
     * Args:
     *     assetID: PHAsset的localIdentifier
     */
    func selectVideo(assetID: String) {
        guard let videoInfo = VideoService.getVideoInfo(assetID: assetID) else {
            onError?("无法获取视频信息")
            return
        }

        saveVideo(videoInfo)
        onStatusUpdate?("视频已选择: \(videoInfo.fileName)")
    }
    
    /**
     * 功能描述: 保存用户选择的视频（从文件）
     * Args:
     *     url: 文件URL
     *     fileName: 文件名
     *     fileSize: 文件大小
     */
    func selectVideoFromFile(url: URL, fileName: String, fileSize: Int64) {
        // 创建一个特殊的 SavedVideoInfo，使用文件路径作为 assetIdentifier
        let videoInfo = SavedVideoInfo(
            assetIdentifier: "file://" + url.path, // 特殊标识：文件路径
            fileName: fileName,
            fileSize: fileSize,
            duration: 0.0, // 文件选择时无法获取时长，设为0
            savedDate: Date()
        )
        
        saveVideo(videoInfo)
        onStatusUpdate?("文件已选择: \(fileName)")
        print("📁 [VideoViewModel] 文件视频已保存")
        print("   - 路径: \(url.path)")
        print("   - 大小: \(fileSize) bytes")
    }

    // MARK: - 一键替换核心流程

    /**
     * 功能描述: 执行一键替换流程
     * 五步流程:
     *     1. 验证素材
     *     2. 在主线程获取微信容器路径（避免线程权限问题）
     *     3. 从相册导出视频（后台线程）
     *     4. 上传到微信 tmp → 查找最新缓存 → 执行替换
     *     5. 清理临时文件
     */
    func executeOneClickReplace(completion: @escaping (Bool) -> Void) {
        print("\n" + String(repeating: "=", count: 80))
        print("🚀 [VideoViewModel] ========== 开始一键替换流程 ==========")
        print(String(repeating: "=", count: 80))
        
        // 步骤1: 验证素材
        print("📝 [步骤1] 验证素材...")
        guard let video = savedVideo else {
            print("❌ [步骤1] 失败：未选择素材")
            onError?("请先选择素材")
            completion(false)
            return
        }
        print("✅ [步骤1] 成功：素材已选择")
        print("   - 文件名: \(video.fileName)")
        print("   - 大小: \(video.formattedFileSize())")
        print("   - 时长: \(video.formattedDuration())")

        // 步骤2A: 使用预先缓存的微信容器路径
        // ⚠️ 重要：由于 iOS 私有权限可能不允许在 UIAlertController callback 中使用
        //         我们在显示 alert 之前就获取并缓存了路径
        print("\n📝 [步骤2A] 使用缓存的微信容器路径...")
        print("   - 当前线程: \(Thread.current)")
        print("   - 是否主线程: \(Thread.isMainThread)")
        
        let wechatTmpPath: String
        if let cachedPath = cachedWechatTmpPath {
            print("✅ [步骤2A] 成功：使用缓存路径")
            wechatTmpPath = cachedPath
        } else {
            print("⚠️ [步骤2A] 缓存的路径不存在，尝试直接获取...")
            print("   - 提示：这不应该发生，说明 prefetchWechatPath() 没有被调用")
            guard let path = WechatService.getWechatTmpPath() else {
                print("❌ 直接获取也失败了")
                print("\n🔍 运行完整诊断...")
                let diagnosticResults = WechatService.diagnoseContainerAccess()
                for line in diagnosticResults {
                    print("   \(line)")
                }
                print(String(repeating: "=", count: 80))
                onError?("找不到微信应用，请确保微信已安装\n\n提示：请查看 Xcode Console 中的详细日志")
                completion(false)
                return
            }
            cachedWechatTmpPath = path
            wechatTmpPath = path
            print("✅ 直接获取成功，已更新缓存")
        }
        print("   - 路径: \(wechatTmpPath)")
        
        onStatusUpdate?("正在从相册导出素材...")

        // 步骤2B: 从相册导出视频（在后台线程执行）
        print("\n📝 [步骤2B] 从相册导出视频（后台线程）...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                print("❌ [步骤2B] self 已释放")
                return
            }
            
            print("   - 当前线程: \(Thread.current)")
            print("   - AssetID: \(video.assetIdentifier.prefix(20))...")
            
            let result = VideoService.exportVideoFromPhotos(assetID: video.assetIdentifier)

            switch result {
            case .success(let (tempPath, fileName)):
                print("✅ [步骤2B] 成功：视频导出完成")
                print("   - 临时路径: \(tempPath)")
                print("   - 文件名: \(fileName)")
                
                // ⚠️ 重要：必须回到主线程执行后续操作
                // 因为访问微信容器需要私有权限，而这些权限可能只在主线程有效
                DispatchQueue.main.async {
                    self.onStatusUpdate?("导出成功，正在上传素材...")
                    print("📝 [步骤2B] 切换回主线程继续...")
                    print("   - 当前线程: \(Thread.current)")
                    print("   - 是否主线程: \(Thread.isMainThread)")
                    
                    // 在主线程执行后续操作
                    self.proceedWithUpload(tempPath: tempPath, fileName: fileName, wechatTmpPath: wechatTmpPath, completion: completion)
                }

            case .failure(let error):
                print("❌ [步骤2B] 失败：视频导出失败")
                print("   - 错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onError?("导出失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    /**
     * 功能描述: 继续执行上传和替换流程
     * Args:
     *     tempPath: 导出的临时文件路径
     *     fileName: 文件名
     *     wechatTmpPath: 微信 tmp 目录路径（已在主线程获取）
     *     completion: 完成回调
     */
    private func proceedWithUpload(tempPath: String, fileName: String, wechatTmpPath: String, completion: @escaping (Bool) -> Void) {
        print("\n📝 [步骤3] 上传素材到微信 tmp...")
        print("   - 当前线程: \(Thread.current)")
        print("   - 是否主线程: \(Thread.isMainThread)")
        print("   - 源文件: \(tempPath)")
        print("   - 目标路径: \(wechatTmpPath)/\(fileName)")
        
        // 验证微信 tmp 目录是否存在
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let tmpExists = fm.fileExists(atPath: wechatTmpPath, isDirectory: &isDir)
        print("   - 微信 tmp 存在: \(tmpExists), 是目录: \(isDir.boolValue)")
        
        if !tmpExists {
            print("❌ [步骤3] 微信 tmp 目录不存在！")
            print("   - 尝试重新定位微信容器...")
            
            // 尝试重新获取路径
            if let newPath = WechatService.getWechatTmpPath() {
                print("✅ 重新定位成功: \(newPath)")
                // 递归调用，使用新路径
                self.proceedWithUpload(tempPath: tempPath, fileName: fileName, wechatTmpPath: newPath, completion: completion)
                return
            } else {
                print("❌ 重新定位失败")
                DispatchQueue.main.async {
                    self.onError?("找不到微信应用，请确保微信已安装")
                }
                FileService.cleanupTempFile(at: tempPath)
                completion(false)
                return
            }
        }

        let destinationPath = "\(wechatTmpPath)/\(fileName)"
        print("   - 开始复制文件...")
        let copyResult = FileService.copyFile(from: tempPath, to: destinationPath)

        switch copyResult {
        case .success:
            print("✅ [步骤3] 成功：素材已上传到微信")
            DispatchQueue.main.async {
                self.onStatusUpdate?("素材已上传，正在查找最新缓存...")
            }
            self.proceedWithReplace(tmpPath: wechatTmpPath, fileName: fileName, tempPath: tempPath, completion: completion)

        case .failure(let error):
            print("❌ [步骤3] 失败：上传素材失败")
            print("   - 错误: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.onError?("上传失败: \(error.localizedDescription)")
            }
            FileService.cleanupTempFile(at: tempPath)
            completion(false)
        }
    }

    /**
     * 功能描述: 继续执行替换流程
     */
    private func proceedWithReplace(tmpPath: String, fileName: String, tempPath: String, completion: @escaping (Bool) -> Void) {
        print("\n📝 [步骤4] 查找最新视频缓存...")
        print("   - 当前线程: \(Thread.current)")
        print("   - 是否主线程: \(Thread.isMainThread)")
        print("   - 查找路径: \(tmpPath)")
        print("   - 查找前缀: LocalShortVideo")
        
        // 先验证 tmp 目录状态
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let tmpExists = fm.fileExists(atPath: tmpPath, isDirectory: &isDir)
        print("   - tmp 目录存在: \(tmpExists), 是目录: \(isDir.boolValue)")
        
        if tmpExists && isDir.boolValue {
            // 列出 tmp 目录内容
            if let contents = try? fm.contentsOfDirectory(atPath: tmpPath) {
                print("   - tmp 目录包含 \(contents.count) 个文件")
                let shortVideoFiles = contents.filter { $0.contains("LocalShortVideo") }
                print("   - 其中 LocalShortVideo 文件: \(shortVideoFiles.count) 个")
                for file in shortVideoFiles {
                    print("     • \(file)")
                }
            } else {
                print("   - ⚠️ 无法读取 tmp 目录内容")
            }
        }
        
        guard let cacheFileName = WechatService.findLatestVideoCache(in: tmpPath) else {
            print("❌ [步骤4] 失败：未找到微信视频缓存")
            print("   提示：请先在微信中录制一个视频（但不发布）")
            DispatchQueue.main.async {
                self.onError?("找不到微信视频缓存\n请先在微信中开始发布视频，然后退出再试")
            }
            FileService.cleanupTempFile(at: tempPath)
            completion(false)
            return
        }
        
        print("✅ [步骤4] 成功：找到最新缓存")
        print("   - 缓存文件: \(cacheFileName)")

        DispatchQueue.main.async {
            self.onStatusUpdate?("找到缓存文件，正在替换...")
        }

        print("\n📝 [步骤5] 执行文件替换...")
        print("   - 当前线程: \(Thread.current)")
        print("   - 是否主线程: \(Thread.isMainThread)")
        print("   - 我们的文件: \(fileName)")
        print("   - 替换目标: \(cacheFileName)")
        print("   - 操作目录: \(tmpPath)")
        
        // 验证文件存在性
        let ourFilePath = "\(tmpPath)/\(fileName)"
        let cacheFilePath = "\(tmpPath)/\(cacheFileName)"
        print("   - 我们文件存在: \(fm.fileExists(atPath: ourFilePath))")
        print("   - 缓存文件存在: \(fm.fileExists(atPath: cacheFilePath))")
        
        let replaceResult = FileService.replaceVideo(
            ourFileName: fileName,
            cacheFileName: cacheFileName,
            in: tmpPath
        )

        switch replaceResult {
        case .success:
            print("✅ [步骤5] 成功：文件替换完成")
            print("\n" + String(repeating: "=", count: 80))
            print("🎉 一键替换流程完成！")
            print(String(repeating: "=", count: 80) + "\n")
            DispatchQueue.main.async {
                self.onStatusUpdate?("替换成功！可以去微信发布了 ✓")
            }
            FileService.cleanupTempFile(at: tempPath)
            completion(true)

        case .failure(let error):
            print("❌ [步骤5] 失败：文件替换失败")
            print("   - 错误: \(error.localizedDescription)")
            print(String(repeating: "=", count: 80))
            DispatchQueue.main.async {
                self.onError?("替换失败: \(error.localizedDescription)")
            }
            FileService.cleanupTempFile(at: tempPath)
            completion(false)
        }
    }
}
