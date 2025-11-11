# 微信视频替换工具 - 项目文档

> 最后更新：2025-01-10 23:30

## 📁 项目结构

```
视频测试/
├── README.md                          # 本文档 - 项目总览和当前状态
├── 01-需求文档.md                      # 完整需求规格（已更新）
├── 02-实现方案.md                      # 技术实现详细说明
├── 开发指南-简化版.md                   # 快速开发参考
├── WechatVideoReplacer/               # Xcode 项目根目录
│   ├── Makefile                       # 构建和打包脚本
│   ├── WechatVideoReplacer.xcodeproj/ # Xcode 项目文件
│   ├── WechatVideoReplacer/           # 应用源码目录
│   │   ├── AppDelegate.swift
│   │   ├── ViewController.swift       # 主界面（需重构）
│   │   ├── Models/                    # 数据模型
│   │   │   └── SavedVideoInfo.swift   # ✅ 已完成
│   │   ├── Services/                  # 业务服务
│   │   │   ├── VideoService.swift     # ✅ 已完成 - 相册操作
│   │   │   ├── WechatService.swift    # ✅ 部分完成 - 容器定位
│   │   │   └── FileService.swift      # 🚧 待完善
│   │   ├── ViewModels/                # 视图模型
│   │   │   └── VideoViewModel.swift   # 🚧 待实现
│   │   ├── Utils/                     # 工具类
│   │   │   └── Constants.swift        # ✅ 已完成
│   │   ├── entitlements.plist         # ✅ 完整权限配置
│   │   └── Info.plist
│   ├── WechatVideoReplacer.ipa        # 最新构建的 IPA（76KB）
│   └── build/                         # 编译输出目录
└── [测试视频文件]                      # *.mp4 测试素材
```

**已清理的内容**（不再需要）：
- ✅ 22个 RootHelper 调试文档
- ✅ 9个分析和对比文档
- ✅ FilzaAnalysis 目录
- ✅ RootHelper 源码目录（代码层面待清理）
- ✅ 各种日志文件

---

## ✅ 已完成的工作

### 阶段1：权限突破（已完成 ✓）

#### 1.1 容器访问权限验证
**目标**：突破 iOS 沙盒限制，访问微信应用容器

**尝试方案对比**：

| 方案 | 状态 | 结果 | 原因 |
|------|------|------|------|
| RootHelper + spawnRoot | ❌ 失败 | Operation not permitted | iOS 17.6+ 限制，且不需要 root |
| SC_Info 文件夹（未签名） | ❌ 失败 | Permission denied | TrollStore 未注入 entitlements |
| ldid 预签名（有禁止权限） | ❌ 闪退 | App crash on launch | 包含被禁止的 entitlements |
| **ldid 签名（安全权限）** | ✅ **成功** | **完全可用** | **最终方案** |

#### 1.2 最终成功方案

**核心技术**：
- ✅ 使用 ldid 对主应用签名
- ✅ 嵌入完整的 entitlements（参考 Filza）
- ✅ 移除被禁止的 entitlements
- ✅ 通过 TrollStore 安装

**关键 entitlements**（已验证可用）：
```xml
<!-- 三个核心权限 -->
<key>com.apple.security.exception.files.absolute-path.read-write</key>
<array><string>/</string></array>

<key>com.apple.private.security.container-manager</key>
<true/>

<key>com.apple.private.MobileContainerManager.allowed</key>
<true/>
```

**验证结果**：
```
✅ 成功读取 208 个容器
✅ 找到微信容器：com.tencent.xin
   UUID: 91FC0093-DD75-4AA3-BC68-27956F0DD056
   路径: /var/mobile/Containers/Data/Application/91FC0093-DD75-4AA3-BC68-27956F0DD056
   
✅ Documents: 存在，包含 21 个项目
✅ Library: 存在
```

#### 1.3 签名和打包流程（Makefile）

**编译配置**：
```makefile
CODE_SIGNING_REQUIRED = NO
CODE_SIGNING_ALLOWED = NO
```

**签名流程**：
```bash
# 1. Archive（Xcode 编译，不签名）
xcodebuild archive -project ... -configuration Release

# 2. 用 ldid 签名主应用
ldid -Sentitlements.plist WechatVideoReplacer.app/WechatVideoReplacer

# 3. 验证 entitlements 已嵌入
ldid -e WechatVideoReplacer.app/WechatVideoReplacer | grep "container-manager"

# 4. 打包 IPA
zip -qr WechatVideoReplacer.ipa Payload
```

**输出**：
- IPA 文件：76KB
- 签名状态：ldid 签名，无 Apple 证书
- 安装方式：TrollStore

---

## 🔄 进行中的工作

### 阶段2：核心功能实现（进行中 🚧）

#### 2.1 已完成的代码

**文件结构**：
```
WechatVideoReplacer/
├── Models/
│   └── SavedVideoInfo.swift         # ✅ 已创建 - 数据模型
├── Services/
│   ├── VideoService.swift            # ✅ 已创建 - 相册操作
│   ├── WechatService.swift           # ✅ 已完成 - 容器定位（直接访问）
│   └── FileService.swift             # 🚧 需要完善 - 文件操作
├── ViewModels/
│   └── VideoViewModel.swift          # 🚧 待实现 - 一键替换流程
├── Views/
│   └── ViewController.swift          # 🚧 需重构 - 当前是测试UI
└── Utils/
    └── Constants.swift                # ✅ 已创建 - 常量定义
```

#### 2.2 已实现的功能

**WechatService.swift**（核心已完成）：
- ✅ `findWechatContainer()` - 定位微信容器（直接访问方式）
- ✅ `scanAllContainersDirect()` - 扫描所有容器并诊断
- ⚠️ 待添加：`findLatestVideoCache()` - 查找最新缓存
- ⚠️ 待添加：`replaceVideo()` - 执行文件替换

**VideoService.swift**（已创建）：
- ✅ `requestPhotoLibraryAccess()` - 请求相册权限
- ✅ `exportVideoFromPhotos()` - 从相册导出视频
- ✅ `getVideoInfo()` - 获取视频信息

**SavedVideoInfo.swift**（已创建）：
- ✅ 数据模型定义
- ✅ `VideoStorageManager` - 持久化管理

#### 2.3 待实现的功能

**必须完成的任务**：
1. ❌ 清理项目：移除 RootHelper 相关代码
   - 删除 `roothelper` binary
   - 删除 `RootHelperService.swift`
   - 删除 `TSUtil.h/m`
   - 清理 Info.plist 中的 `TSRootBinaries`

2. ❌ 完善 WechatService
   - 添加查找最新缓存方法
   - 添加文件替换方法
   - 完善错误处理

3. ❌ 实现 VideoViewModel
   - 一键替换完整流程（7步）
   - 状态管理
   - 进度反馈

4. ❌ 重构 UI
   - 移除测试按钮
   - 实现素材选择界面
   - 实现一键替换按钮
   - 实现进度显示

---

## 📖 文档说明

### 核心文档（必读）

1. **README.md**（本文档）
   - 项目总览
   - 已完成工作记录
   - 技术方案说明

2. **01-需求文档.md**
   - 完整的功能需求
   - 用户界面设计
   - 验收标准

3. **02-实现方案.md**（新建）
   - 详细的技术实现
   - 代码示例
   - 最佳实践

4. **03-开发进度.md**（新建）
   - 详细的任务清单
   - 进度跟踪
   - 遇到的问题和解决方案

### 参考文档（可选）

- `开发指南-简化版.md` - 快速开发参考
- `Makefile` - 构建和打包脚本

### 已清理的废弃内容（✅ 完成）

**项目根目录**（9个文档已删除）：
- ✅ `CONTAINER_ANALYSIS_COMPARISON.md`
- ✅ `CONTAINER_CHECKLIST.md`
- ✅ `FILZA_REVERSE_GUIDE.md`
- ✅ `container_architecture.md`
- ✅ `filza_architecture_analysis.md`
- ✅ `auto_reverse_filza.sh`
- ✅ `frida_ai_analyzer.py`
- ✅ `开发提示词.md`
- ✅ `打包和验收标准.md`

**WechatVideoReplacer 目录**（22个调试文档 + 废弃目录已删除）：
- ✅ 所有 RootHelper 相关调试文档（22个）
- ✅ `FilzaAnalysis/` 和 `FilzaAnalysis_New/` 目录
- ✅ `RootHelper/` 源码目录（文件已删，代码引用待清理）
- ✅ `Payload/` 解包目录
- ✅ `Filza_4.0_新版.ipa`
- ✅ 所有 `.log` 文件

**总计清理**：31个废弃文档 + 4个废弃目录 + 大量日志文件

---

## 🔑 关键技术方案

### 1. 容器访问方式

**最终选择：直接访问（无需 RootHelper）**

```swift
func findWechatContainer() -> String? {
    let fm = FileManager.default
    let basePath = "/var/mobile/Containers/Data/Application/"
    
    // 使用 container-manager entitlement 直接读取
    guard let containers = try? fm.contentsOfDirectory(atPath: basePath) else {
        return nil
    }
    
    for uuid in containers {
        let metadataPath = "\(basePath)\(uuid)/.com.apple.mobile_container_manager.metadata.plist"
        
        if let metadata = NSDictionary(contentsOfFile: metadataPath),
           let bundleID = metadata["MCMMetadataIdentifier"] as? String,
           bundleID == "com.tencent.xin" {
            return "\(basePath)\(uuid)"
        }
    }
    return nil
}
```

### 2. 权限配置

**完整的 entitlements.plist**：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.private.security.container-required</key>
    <false/>
    
    <key>platform-application</key>
    <true/>
    
    <key>com.apple.security.exception.files.absolute-path.read-write</key>
    <array><string>/</string></array>
    
    <key>com.apple.security.files.all</key>
    <true/>
    
    <key>com.apple.private.security.no-container</key>
    <true/>
    
    <key>com.apple.private.security.storage.AppDataContainers</key>
    <true/>
    
    <key>com.apple.private.security.container-manager</key>
    <true/>
    
    <key>com.apple.private.MobileContainerManager.allowed</key>
    <true/>
    
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <key>com.apple.security.files.root.read-only</key>
    <true/>
    
    <key>com.apple.security.files.root.read-write</key>
    <true/>
    
    <key>com.apple.security.application-groups</key>
    <array><string>*</string></array>
    
    <key>task_for_pid-allow</key>
    <true/>
    
    <key>get-task-allow</key>
    <true/>
    
    <key>com.apple.private.security.no-sandbox</key>
    <true/>
    
    <key>com.apple.private.persona-mgmt</key>
    <true/>
</dict>
</plist>
```

**⚠️ 禁止使用（会闪退）**：
- ❌ `com.apple.private.cs.debugger`
- ❌ `com.apple.private.skip-library-validation`
- ❌ `dynamic-codesigning`

### 3. 签名流程

**Makefile 配置**：
```makefile
sign:
    # 用 ldid 签名主应用
    ldid -SWechatVideoReplacer/entitlements.plist $(APP_PATH)/WechatVideoReplacer
    
    # 验证 entitlements 已嵌入
    ldid -e $(APP_PATH)/WechatVideoReplacer | grep "container-manager"
    
    # 验证无禁止的 entitlements
    if ldid -e $(APP_PATH)/WechatVideoReplacer | grep -q "cs.debugger\|skip-library-validation"; then
        echo "❌ ERROR: Banned entitlements found!"
        exit 1
    fi
```

---

## 🎯 下一步计划

### 立即执行

1. **清理项目**（优先级：高）
   - 移除所有 RootHelper 相关代码
   - 删除废弃文档
   - 重命名主要文档

2. **完善核心服务**（优先级：高）
   - 完成 WechatService 的剩余方法
   - 实现文件替换逻辑
   - 添加错误处理

3. **实现完整流程**（优先级：高）
   - 创建 VideoViewModel
   - 实现一键替换流程
   - 重构 UI

### 后续任务

4. **测试验证**
   - 功能测试
   - 错误场景测试
   - 性能测试

5. **打包交付**
   - 生成最终 IPA
   - 编写使用文档

---

## 📝 重要笔记

### 成功经验

1. **参考 Filza 是正确的决策**
   - 通过反编译 Filza 找到了正确的 entitlements
   - Filza 的方式就是直接访问，不需要 RootHelper

2. **ldid 签名是关键**
   - TrollStore 需要读取已嵌入的 entitlements
   - 不能用 Apple 证书预签名（会冲突）

3. **移除被禁止的 entitlements 解决了闪退**
   - iOS 15+ A12+ 设备禁止某些 entitlements
   - 必须移除 `cs.debugger` 和 `skip-library-validation`

### 失败教训

1. **RootHelper 方案走了弯路**
   - 花费大量时间调试 roothelper
   - 最终发现完全不需要 root 权限
   - 直接访问方式更简单可靠

2. **文档混乱导致方向迷失**
   - 产生了太多分析文档
   - 没有及时记录成功方案
   - 需要定期整理文档

---

## 🔗 相关链接

- Xcode 项目：`./WechatVideoReplacer/`
- 构建脚本：`./Makefile`
- 完整需求：`./01-需求文档.md`
- 实现细节：`./02-实现方案.md`
- 开发进度：`./03-开发进度.md`

---

**当前状态**：✅ 权限突破完成 → 🚧 核心功能实现中

**最后更新**：2025-01-10 23:30
