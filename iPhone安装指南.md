# iPhone SE2 巨魔安装指南

## 📦 安装文件

**最新 IPA（包含 BSPHP 授权）：**
```
/Users/slwl/bc/微信开发/视频测试/WechatVideoReplacer/build/WechatVideoReplacer.ipa
```

## 📱 iPhone SE2 + 巨魔商店安装

### 方法 1：AirDrop 传输（推荐 ⭐）

1. **在 Mac 上：**
   ```bash
   # 打开 IPA 所在文件夹
   open /Users/slwl/bc/微信开发/视频测试/WechatVideoReplacer/build/
   ```

2. **使用 AirDrop：**
   - 在 Finder 中右键点击 `WechatVideoReplacer.ipa`
   - 选择 "共享" → "AirDrop"
   - 选择您的 iPhone SE2

3. **在 iPhone SE2 上：**
   - 接收 AirDrop 文件
   - 点击 "拷贝到 TrollStore"
   - 等待安装完成
   - 在主屏幕找到 "WechatVideoReplacer" 图标

### 方法 2：通过 iCloud Drive / 文件 App

1. **上传到 iCloud：**
   ```bash
   # 复制到 iCloud Drive
   cp /Users/slwl/bc/微信开发/视频测试/WechatVideoReplacer/build/WechatVideoReplacer.ipa ~/Library/Mobile\ Documents/com~apple~CloudDocs/
   ```

2. **在 iPhone SE2 上：**
   - 打开 "文件" App
   - 进入 "iCloud Drive"
   - 找到 `WechatVideoReplacer.ipa`
   - 点击文件，选择 "共享"
   - 选择 "TrollStore"
   - 点击 "Install"

### 方法 3：通过 HTTP 服务器

1. **在 Mac 上启动简单的 HTTP 服务器：**
   ```bash
   cd /Users/slwl/bc/微信开发/视频测试/WechatVideoReplacer/build/
   python3 -m http.server 8000
   ```

2. **查看 Mac 的 IP 地址：**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

3. **在 iPhone SE2 上：**
   - 打开 Safari
   - 访问：`http://Mac的IP地址:8000`
   - 点击 `WechatVideoReplacer.ipa` 下载
   - 下载完成后点击文件
   - 选择 "在 TrollStore 中打开"
   - 点击 "Install"

### 方法 4：通过 USB + 文件共享（如果 AirDrop 不可用）

1. **使用数据线连接 iPhone SE2 到 Mac**

2. **使用 libimobiledevice：**
   ```bash
   # 如果没安装，先安装
   # brew install libimobiledevice
   
   # 推送文件
   ideviceinstaller -i /Users/slwl/bc/微信开发/视频测试/WechatVideoReplacer/build/WechatVideoReplacer.ipa
   ```

## 🧪 测试步骤

### 1. 创建测试卡密

访问：https://km.shenl.vip

1. 登录后台
2. 找到软件 ID：57834999
3. 进入 "卡密管理"
4. 生成 1 个测试卡密：
   - 有效期：30 天
   - 使用次数：1 次（单设备）
   - 备注：iPhone SE2 测试
5. **记录生成的卡号**

### 2. 启动应用测试

1. 在 iPhone SE2 主屏幕点击 "WechatVideoReplacer"
2. 应该看到授权界面（🔐 软件授权验证）
3. 输入刚才生成的测试卡号
4. 如果有密码就输入，没有就留空
5. 点击 "立即验证"

**预期结果：**
- ✅ 显示 "正在连接服务器验证..."
- ✅ 验证成功后显示到期时间和剩余天数
- ✅ 手机震动反馈
- ✅ 2 秒后自动进入主界面（视频替换工具）

### 3. 重启测试

1. 完全关闭应用（从后台划掉）
2. 重新启动应用
3. **预期：直接进入主界面，不再要求输入卡密**

### 4. 使用视频替换功能

1. 点击 "选择容器" 按钮
2. 找到微信容器
3. 导出视频 / 替换视频
4. **确认所有功能正常工作**

## 📊 查看日志（如果遇到问题）

### 方法 1：在 Mac 上查看 iPhone 日志

```bash
# 通过 USB 连接 iPhone SE2，然后运行：
idevicesyslog | grep -E "\[BSPHP\]|\[授权\]"

# 或者只看授权相关：
idevicesyslog | grep "License"
```

### 方法 2：使用 Console.app

1. 在 Mac 上打开 "控制台" (Console.app)
2. 通过 USB 连接 iPhone SE2
3. 在左侧选择您的 iPhone
4. 在搜索框输入 "BSPHP" 或 "授权"
5. 运行应用，观察实时日志

## ❓ 常见问题

### Q1: AirDrop 找不到设备？
**解决：**
- 确保 Mac 和 iPhone 都开启了 WiFi 和蓝牙
- 在 iPhone 上打开控制中心，长按 AirDrop 图标
- 选择 "所有人" 或 "仅限联系人"

### Q2: TrollStore 安装失败？
**可能原因：**
- TrollStore 版本过旧，需要更新
- iOS 系统不兼容
- 证书问题

**解决：**
- 更新 TrollStore 到最新版本
- 检查 TrollStore 状态

### Q3: 验证按钮点击后没反应？
**检查：**
- iPhone 是否联网（WiFi 或移动数据）
- 查看日志确认具体错误
- 确认输入的卡号正确

### Q4: 显示 "版本不匹配"？
**解决：**
- 登录 BSPHP 后台
- 找到软件 ID 57834999
- 检查 "软件版本" 设置
- 确保设置为 `v1.0`

### Q5: 如何重新测试授权流程？
**清除授权数据：**
1. 卸载应用
2. 重新安装
3. 重新输入卡密

## ✅ 成功标志

如果一切正常，您应该看到：

1. ✅ 首次启动显示授权界面
2. ✅ 输入测试卡密后验证成功
3. ✅ 显示 "✅ 验证成功！到期时间：XXXX-XX-XX，剩余 XX 天"
4. ✅ 手机震动反馈
5. ✅ 自动进入主界面
6. ✅ 视频替换功能正常
7. ✅ 重启后不需要重新输入卡密

达到以上标准，说明 BSPHP 授权功能在 iPhone SE2 上运行正常！🎉

## 📱 设备信息

- **设备型号**：iPhone SE2
- **安装方式**：TrollStore（巨魔商店）
- **iOS 版本**：任何支持 TrollStore 的版本
- **应用大小**：120KB
- **权限要求**：网络访问（用于授权验证）

## 🔧 技术细节

- **服务器**：https://km.shenl.vip
- **软件 ID**：57834999
- **版本**：v1.0
- **设备识别**：IDFV（iPhone 标识符，无需用户授权）
- **加密方式**：DES3 + MD5 双重签名
- **授权存储**：UserDefaults（本地持久化）

有任何问题随时查看日志或询问！
