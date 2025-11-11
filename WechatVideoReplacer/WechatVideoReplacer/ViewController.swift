//
//  ViewController.swift
//  WechatVideoReplacer
//
//  Created by 神龙网络 on 2025/11/9.
//

import UIKit
import Photos
import PhotosUI
import UniformTypeIdentifiers

/**
 * 功能描述: 主视图控制器 - UI 交互和展示
 */
class ViewController: UIViewController {

    // MARK: - UI 组件

    /// 标题标签
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "微信视频素材替换工具"
        label.font = UIFont.boldSystemFont(ofSize: 26)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 当前素材容器视图
    private let videoInfoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 当前素材标签
    private let currentVideoLabel: UILabel = {
        let label = UILabel()
        label.text = "📹 当前使用的素材:"
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 素材信息标签
    private let videoDetailsLabel: UILabel = {
        let label = UILabel()
        label.text = "未选择素材"
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 更换素材按钮
    private let changeVideoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🔄 更换素材", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        button.layer.cornerRadius = 10
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 一键替换按钮
    private let replaceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🚀 一键替换", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.layer.cornerRadius = 14
        button.backgroundColor = UIColor.systemGreen
        button.setTitleColor(.white, for: .normal)
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 状态标签
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "请先选择素材..."
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 诊断按钮（调试用）
    private let diagnosticButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🔍 系统诊断", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setTitleColor(.systemGray, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    /// 清除缓存按钮（调试用）
    private let clearCacheButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🗑️ 清除缓存", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setTitleColor(.systemRed, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    


    // MARK: - 属性

    private let viewModel = VideoViewModel()
    private var isExecuting = false

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupViewModel()
        checkPermissions()
        updateUI()
    }

    // MARK: - UI 设置

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // 添加所有视图
        view.addSubview(titleLabel)
        view.addSubview(videoInfoContainerView)
        videoInfoContainerView.addSubview(currentVideoLabel)
        videoInfoContainerView.addSubview(videoDetailsLabel)
        view.addSubview(changeVideoButton)
        view.addSubview(replaceButton)
        view.addSubview(statusLabel)
        view.addSubview(diagnosticButton)
        view.addSubview(clearCacheButton)

        // 设置约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            // 素材信息容器
            videoInfoContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            videoInfoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            videoInfoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            // 当前素材标签
            currentVideoLabel.topAnchor.constraint(equalTo: videoInfoContainerView.topAnchor, constant: 20),
            currentVideoLabel.leadingAnchor.constraint(equalTo: videoInfoContainerView.leadingAnchor, constant: 20),
            currentVideoLabel.trailingAnchor.constraint(equalTo: videoInfoContainerView.trailingAnchor, constant: -20),

            // 素材详情标签
            videoDetailsLabel.topAnchor.constraint(equalTo: currentVideoLabel.bottomAnchor, constant: 10),
            videoDetailsLabel.leadingAnchor.constraint(equalTo: videoInfoContainerView.leadingAnchor, constant: 20),
            videoDetailsLabel.trailingAnchor.constraint(equalTo: videoInfoContainerView.trailingAnchor, constant: -20),
            videoDetailsLabel.bottomAnchor.constraint(equalTo: videoInfoContainerView.bottomAnchor, constant: -20),

            // 更换素材按钮
            changeVideoButton.topAnchor.constraint(equalTo: videoInfoContainerView.bottomAnchor, constant: 30),
            changeVideoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            changeVideoButton.widthAnchor.constraint(equalToConstant: 200),
            changeVideoButton.heightAnchor.constraint(equalToConstant: 50),

            // 一键替换按钮
            replaceButton.topAnchor.constraint(equalTo: changeVideoButton.bottomAnchor, constant: 40),
            replaceButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            replaceButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            replaceButton.heightAnchor.constraint(equalToConstant: 64),

            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: replaceButton.bottomAnchor, constant: 30),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            // 诊断按钮（底部左侧）
            diagnosticButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            diagnosticButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            
            // 清除缓存按钮（底部右侧）
            clearCacheButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            clearCacheButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
        ])

        // 添加按钮动作
        changeVideoButton.addTarget(self, action: #selector(changeVideoTapped), for: .touchUpInside)
        replaceButton.addTarget(self, action: #selector(replaceButtonTapped), for: .touchUpInside)
        diagnosticButton.addTarget(self, action: #selector(diagnosticTapped), for: .touchUpInside)
        clearCacheButton.addTarget(self, action: #selector(clearCacheTapped), for: .touchUpInside)
    }

    /**
     * 功能描述: 设置 ViewModel 回调
     */
    private func setupViewModel() {
        viewModel.onStatusUpdate = { [weak self] status in
            DispatchQueue.main.async {
                self?.statusLabel.text = status
            }
        }

        viewModel.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.showAlert(title: "错误", message: error)
                self?.isExecuting = false
                self?.updateButtonStates()
            }
        }
    }

    /**
     * 功能描述: 检查相册权限
     */
    private func checkPermissions() {
        let status = PHPhotoLibrary.authorizationStatus()

        if status == .notDetermined {
            VideoService.requestPhotoLibraryPermission { [weak self] granted in
                if !granted {
                    self?.showAlert(title: "权限不足", message: "需要相册访问权限才能选择视频")
                }
            }
        }
    }

    // MARK: - 按钮动作

    @objc private func changeVideoTapped() {
        guard !isExecuting else { return }

        // 显示选择来源的菜单
        let alert = UIAlertController(title: "选择视频来源", message: "请选择视频的来源", preferredStyle: .actionSheet)

        // 从相册选择
        alert.addAction(UIAlertAction(title: "📱 从相册选择", style: .default) { [weak self] _ in
            self?.selectFromPhotoLibrary()
        })

        // 从文件选择
        alert.addAction(UIAlertAction(title: "📁 从文件选择", style: .default) { [weak self] _ in
            self?.selectFromFiles()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad 适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = changeVideoButton
            popover.sourceRect = changeVideoButton.bounds
        }

        present(alert, animated: true)
    }

    /// 从相册选择视频
    private func selectFromPhotoLibrary() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// 从文件选择视频
    private func selectFromFiles() {
        // 支持所有文件类型，让用户可以选择任何文件（包括没有扩展名的视频）
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        
        print("📁 [Files] 文件选择器已打开，支持所有文件类型")
        
        present(picker, animated: true)
    }

    @objc private func replaceButtonTapped() {
        guard !isExecuting else { return }

        // ⚠️ 重要：在显示 alert 之前预先获取并缓存微信路径
        // iOS 私有权限可能不允许在 UIAlertController callback 中使用
        print("🔍 [Replace] 预先获取并缓存微信容器路径...")
        guard viewModel.prefetchWechatPath() else {
            print("❌ [Replace] 找不到微信应用")
            showAlert(title: "错误", message: "找不到微信应用，请确保微信已安装")
            return
        }
        print("✅ [Replace] 微信容器路径已缓存，可以显示确认对话框")

        // 确认对话框
        let alert = UIAlertController(
            title: "确认替换",
            message: "请确保你已经在微信中录制了一个视频草稿（进入发布页面但未发布）",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "开始替换", style: .default) { [weak self] _ in
            self?.startReplace()
        })

        present(alert, animated: true)
    }

    @objc private func diagnosticTapped() {
        print("🔍 [Diagnostic] 开始系统诊断...")

        // 执行诊断
        let results = WechatService.diagnoseContainerAccess()

        // 显示结果
        let message = results.joined(separator: "\n")

        let alert = UIAlertController(title: "🔍 系统诊断", message: message, preferredStyle: .alert)

        // 添加复制按钮
        alert.addAction(UIAlertAction(title: "复制日志", style: .default) { _ in
            UIPasteboard.general.string = message
            print("📋 [Diagnostic] 日志已复制到剪贴板")
        })

        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))

        present(alert, animated: true)

        // 同时输出到控制台
        print("📋 [Diagnostic] 诊断结果:")
        for line in results {
            print(line)
        }
    }

    @objc private func clearCacheTapped() {
        print("🗑️ [ClearCache] 清除所有缓存...")
        
        let alert = UIAlertController(
            title: "确认清除",
            message: "确定要清除所有缓存吗？\n这将清除已选择的素材信息和微信路径缓存。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            // 清除素材缓存
            VideoStorageManager.shared.clear()
            print("✅ [ClearCache] 已清除素材缓存")
            
            // 清除微信路径缓存
            self?.viewModel.clearWechatPathCache()
            print("✅ [ClearCache] 已清除微信路径缓存")
            
            // 清除所有 UserDefaults（如果需要）
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
                print("✅ [ClearCache] 已清除所有 UserDefaults")
            }
            
            // 重新加载UI
            self?.viewModel.reloadSavedVideo()
            self?.updateUI()
            
            self?.showAlert(title: "成功", message: "所有缓存已清除")
            print("✅ [ClearCache] 清除完成")
        })
        
        present(alert, animated: true)
    }

    /**
     * 功能描述: 开始执行替换流程
     */
    private func startReplace() {
        isExecuting = true
        updateButtonStates()

        viewModel.executeOneClickReplace { [weak self] success in
            DispatchQueue.main.async {
                self?.isExecuting = false
                self?.updateButtonStates()

                if success {
                    self?.showSuccessAlert()
                }
            }
        }
    }

    // MARK: - 辅助方法

    private func updateUI() {
        if let video = viewModel.savedVideo {
            videoDetailsLabel.text = "✓ \(video.fileName)\n\(video.formattedFileSize()) | \(video.formattedDuration())"
            videoDetailsLabel.textColor = .label
            replaceButton.isEnabled = true
            replaceButton.backgroundColor = UIColor.systemGreen
            statusLabel.text = "准备就绪，点击一键替换开始"
        } else {
            videoDetailsLabel.text = "未选择素材"
            videoDetailsLabel.textColor = .secondaryLabel
            replaceButton.isEnabled = false
            replaceButton.backgroundColor = UIColor.systemGray
            statusLabel.text = "请先选择素材"
        }
    }

    private func updateButtonStates() {
        let enabled = !isExecuting
        changeVideoButton.isEnabled = enabled
        replaceButton.isEnabled = enabled && viewModel.savedVideo != nil
        diagnosticButton.isEnabled = enabled
        
        if isExecuting {
            replaceButton.setTitle("⏳ 执行中...", for: .normal)
        } else {
            replaceButton.setTitle("🚀 一键替换", for: .normal)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: "✅ 替换成功",
            message: "素材已成功替换！\n\n现在请:\n1. 打开微信\n2. 进入发布页面\n3. 查看视频是否已替换\n4. 点击发布",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "太好了！", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }

        let itemProvider = result.itemProvider

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            // 获取 PHAsset
            if let assetIdentifier = result.assetIdentifier {
                viewModel.selectVideo(assetID: assetIdentifier)
                updateUI()
            }
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true)
        
        guard let url = urls.first else { return }
        
        print("📁 [Files] 选择文件: \(url.lastPathComponent)")
        print("   - 路径: \(url.path)")
        
        // 开始访问安全范围资源
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ [Files] 无法访问安全范围资源")
            showAlert(title: "错误", message: "无法访问选择的文件")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // 验证文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ [Files] 文件不存在")
            showAlert(title: "错误", message: "选择的文件不存在")
            return
        }
        
        // 获取文件信息
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // 使用文件选择器的视频
            viewModel.selectVideoFromFile(url: url, fileName: url.lastPathComponent, fileSize: fileSize)
            updateUI()
            
            print("✅ [Files] 文件选择成功")
            print("   - 文件名: \(url.lastPathComponent)")
            print("   - 大小: \(fileSize) bytes")
            
        } catch {
            print("❌ [Files] 获取文件信息失败: \(error)")
            showAlert(title: "错误", message: "无法读取文件信息: \(error.localizedDescription)")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        print("📁 [Files] 用户取消选择")
    }
}
