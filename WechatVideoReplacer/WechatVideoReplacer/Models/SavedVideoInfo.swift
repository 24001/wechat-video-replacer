import Foundation

/**
 * 功能描述: 保存的视频素材信息
 */
struct SavedVideoInfo: Codable {
    let assetIdentifier: String  // PHAsset的localIdentifier
    let fileName: String          // 原始文件名
    let fileSize: Int64          // 文件大小(字节)
    let duration: Double         // 视频时长(秒)
    let savedDate: Date          // 保存时间
    
    /**
     * 功能描述: 格式化文件大小显示
     */
    func formattedFileSize() -> String {
        let bytes = Double(fileSize)
        
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
        }
    }
    
    /**
     * 功能描述: 格式化视频时长显示
     */
    func formattedDuration() -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/**
 * 功能描述: 素材信息持久化管理
 */
class VideoStorageManager {
    static let shared = VideoStorageManager()
    private let storageKey = "savedVideoInfo"
    
    /**
     * 功能描述: 保存素材信息
     */
    func save(videoInfo: SavedVideoInfo) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(videoInfo) {
            UserDefaults.standard.set(data, forKey: storageKey)
            UserDefaults.standard.synchronize()
            print("✓ 已保存素材信息: \(videoInfo.fileName)")
        }
    }
    
    /**
     * 功能描述: 加载保存的素材信息
     */
    func load() -> SavedVideoInfo? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        let info = try? decoder.decode(SavedVideoInfo.self, from: data)
        
        if let info = info {
            print("✓ 已加载素材信息: \(info.fileName)")
        }
        
        return info
    }
    
    /**
     * 功能描述: 清除保存的素材信息
     */
    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.synchronize()
        print("✓ 已清除素材信息")
    }
}
