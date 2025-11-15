# 微信视频替换工具

iOS 应用，用于替换微信中的视频文件。

## 功能特点

- ✅ 卡密授权验证（支持 BSPHP 网络验证）
- ✅ 访问微信容器目录
- ✅ 替换指定视频文件
- ✅ iOS 真机运行（通过 TrollStore 安装）
- ✅ 用户友好的错误提示

## 快速开始

详细安装和使用说明请查看：
- [快速开始指南](快速开始.md)
- [iPhone 安装指南](iPhone安装指南.md)

## 项目文档

- [修复历史](docs/修复历史.md) - 完整的问题修复记录
- [闪退问题修复说明](闪退问题修复说明.md) - 真机闪退问题详解

## 构建说明

### 环境要求
- Xcode 15.0+
- iOS 14.0+
- Swift 5.0+

### 构建步骤

```bash
# 1. 进入项目目录
cd WechatVideoReplacer

# 2. 构建 Release 版本
xcodebuild -project WechatVideoReplacer.xcodeproj \
  -scheme WechatVideoReplacer \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_BITCODE=NO \
  build

# 3. 使用 ldid 签名
ldid -Sentitlements_safe.plist \
  build/Build/Products/Release-iphoneos/WechatVideoReplacer.app/WechatVideoReplacer

# 4. 打包 IPA
mkdir -p Payload
cp -r build/Build/Products/Release-iphoneos/WechatVideoReplacer.app Payload/
zip -qr WechatVideoReplacer.ipa Payload
rm -rf Payload
```

## 技术栈

- **语言**: Swift 5.0
- **UI**: UIKit (代码构建界面)
- **网络**: URLSession + BSPHP 加密验证
- **加密**: DES3-CBC + MD5
- **签名**: ldid (TrollStore 兼容)

## 最近更新

### 2025-11-15
- ✅ 修复真机闪退问题（Bundle ID、启动测试、退出方式）
- ✅ 优化错误提示（用户友好的错误信息）
- ✅ 改进项目文档结构

### 2025-11-12
- ✅ 修复 Base64 换行符问题（真机签名验证失败）
- ✅ 修正时间戳格式（YYYY → yyyy）

### 2025-11-11
- ✅ 修复 URL 编码问题（+ 号转换为 %2B）
- ✅ 实现 BSPHP 网络验证集成

## 系统要求

- iOS 14.0+
- 需要越狱或使用 TrollStore
- 测试设备：iPhone 11, iOS 17.6

## 许可证

本项目仅供学习和研究使用。
