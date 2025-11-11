import Foundation

/**
 * 功能描述: 微信相关常量定义
 */
struct WechatConstants {
    /// 微信Bundle ID
    static let bundleID = "com.tencent.xin"

    /// iOS容器基础路径
    static let containerBasePath = "/var/mobile/Containers/Data/Application/"

    /// 容器元数据文件名
    static let metadataFile = ".com.apple.mobile_container_manager.metadata.plist"

    /// 元数据中Bundle ID的键名
    static let metadataKeyBundleID = "MCMMetadataIdentifier"

    /// 微信视频缓存文件前缀
    static let videoCachePrefix = "LocalShortVideo"
}

/**
 * 功能描述: 数据存储相关常量
 */
struct StorageKeys {
    /// UserDefaults中保存视频信息的键
    static let savedVideoInfo = "savedVideoInfo"
}

/**
 * 功能描述: UI相关常量
 */
struct UIConstants {
    /// 主色调
    static let primaryColor = "#007AFF"

    /// 成功颜色
    static let successColor = "#34C759"

    /// 错误颜色
    static let errorColor = "#FF3B30"
}
