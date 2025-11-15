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
 * 功能描述: 主视图控制器 - iOS 系统设置风格
 */
class ViewController: UIViewController {

    // MARK: - UI 组件

    /// 主表格视图
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.delegate = self
        table.dataSource = self
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .systemGroupedBackground

        // 注册 Cell
        table.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        return table
    }()

    // MARK: - 属性

    private let viewModel = VideoViewModel()
    private var isExecuting = false

    // 表格数据源枚举
    private enum Section: Int, CaseIterable {
        case videoInfo    // 素材信息
        case actions      // 操作按钮
        case tools        // 工具

        var title: String? {
            switch self {
            case .videoInfo: return "当前素材"
            case .actions: return nil
            case .tools: return "工具"
            }
        }

        var footer: String? {
            switch self {
            case .videoInfo: return nil
            case .actions: return "请确保已在微信中录制视频草稿后再执行替换"
            case .tools: return nil
            }
        }
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupViewModel()
        checkPermissions()
    }

    // MARK: - UI 设置

    private func setupUI() {
        title = "微信视频替换"
        view.backgroundColor = .systemGroupedBackground

        // 添加表格视图
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /**
     * 功能描述: 设置 ViewModel 回调
     */
    private func setupViewModel() {
        viewModel.onStatusUpdate = { [weak self] status in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }

        viewModel.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.showAlert(title: "错误", message: error)
                self?.isExecuting = false
                self?.tableView.reloadData()
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
        let alert = UIAlertController(title: "选择视频来源", message: nil, preferredStyle: .actionSheet)

        // 从相册选择
        alert.addAction(UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
            self?.selectFromPhotoLibrary()
        })

        // 从文件选择
        alert.addAction(UIAlertAction(title: "从文件选择", style: .default) { [weak self] _ in
            self?.selectFromFiles()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad 适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
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
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = self
        picker.allowsMultipleSelection = false

        print("📁 [Files] 文件选择器已打开")

        present(picker, animated: true)
    }

    @objc private func replaceButtonTapped() {
        guard !isExecuting else { return }

        // 预先获取并缓存微信路径
        print("🔍 [Replace] 预先获取并缓存微信容器路径...")
        guard viewModel.prefetchWechatPath() else {
            print("❌ [Replace] 找不到微信应用")
            showAlert(title: "错误", message: "找不到微信应用，请确保微信已安装")
            return
        }
        print("✅ [Replace] 微信容器路径已缓存")

        // 确认对话框
        let alert = UIAlertController(
            title: "确认替换",
            message: "请确保已在微信中录制视频草稿（进入发布页面但未发布）",
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

        let results = WechatService.diagnoseContainerAccess()
        let message = results.joined(separator: "\n")

        let alert = UIAlertController(title: "系统诊断", message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "复制日志", style: .default) { _ in
            UIPasteboard.general.string = message
            print("📋 [Diagnostic] 日志已复制到剪贴板")
        })

        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))

        present(alert, animated: true)

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
            VideoStorageManager.shared.clear()
            print("✅ [ClearCache] 已清除素材缓存")

            self?.viewModel.clearWechatPathCache()
            print("✅ [ClearCache] 已清除微信路径缓存")

            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
                print("✅ [ClearCache] 已清除所有 UserDefaults")
            }

            self?.viewModel.reloadSavedVideo()
            self?.tableView.reloadData()

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
        tableView.reloadData()

        viewModel.executeOneClickReplace { [weak self] success in
            DispatchQueue.main.async {
                self?.isExecuting = false
                self?.tableView.reloadData()

                if success {
                    self?.showSuccessAlert()
                }
            }
        }
    }

    // MARK: - 辅助方法

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: "替换成功",
            message: "素材已成功替换！\n\n现在请:\n1. 打开微信\n2. 进入发布页面\n3. 查看视频是否已替换\n4. 点击发布",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }

        switch sectionType {
        case .videoInfo:
            return 1
        case .actions:
            return 2  // 更换素材 + 一键替换
        case .tools:
            return 2  // 系统诊断 + 清除缓存
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        // 使用 iOS 14+ 的配置 API
        var content = cell.defaultContentConfiguration()

        switch sectionType {
        case .videoInfo:
            configureVideoInfoCell(content: &content)
        case .actions:
            configureActionCell(content: &content, row: indexPath.row)
        case .tools:
            configureToolCell(content: &content, row: indexPath.row)
        }

        cell.contentConfiguration = content
        cell.accessoryType = sectionType == .tools ? .disclosureIndicator : .none

        return cell
    }

    // 配置素材信息 Cell
    private func configureVideoInfoCell(content: inout UIListContentConfiguration) {
        if let video = viewModel.savedVideo {
            // 已选择素材
            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: "video.fill")
            }
            content.imageProperties.tintColor = .systemBlue
            content.text = video.fileName
            content.secondaryText = "\(video.formattedFileSize()) • \(video.formattedDuration())"
        } else {
            // 未选择素材
            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: "video.badge.plus")
            }
            content.imageProperties.tintColor = .systemGray
            content.text = "未选择素材"
            content.secondaryText = "点击下方\"更换素材\"选择视频"
            content.textProperties.color = .secondaryLabel
        }
    }

    // 配置操作按钮 Cell
    private func configureActionCell(content: inout UIListContentConfiguration, row: Int) {
        if row == 0 {
            // 更换素材
            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: "arrow.triangle.2.circlepath")
            }
            content.imageProperties.tintColor = .systemBlue
            content.text = "更换素材"
            content.secondaryText = "从相册或文件选择视频"
        } else {
            // 一键替换
            let hasVideo = viewModel.savedVideo != nil
            let isEnabled = hasVideo && !isExecuting

            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: isExecuting ? "hourglass" : "play.fill")
            }
            content.imageProperties.tintColor = isEnabled ? .systemGreen : .systemGray
            content.text = isExecuting ? "执行中..." : "一键替换"
            content.secondaryText = hasVideo ? "替换微信视频草稿" : "请先选择素材"
            content.textProperties.color = isEnabled ? .label : .secondaryLabel
        }
    }

    // 配置工具 Cell
    private func configureToolCell(content: inout UIListContentConfiguration, row: Int) {
        if row == 0 {
            // 系统诊断
            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: "stethoscope")
            }
            content.imageProperties.tintColor = .systemGray
            content.text = "系统诊断"
            content.secondaryText = "检查权限和路径配置"
        } else {
            // 清除缓存
            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: "trash")
            }
            content.imageProperties.tintColor = .systemRed
            content.text = "清除缓存"
            content.secondaryText = "清空素材和路径缓存"
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return Section(rawValue: section)?.footer
    }
}

// MARK: - UITableViewDelegate

extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        switch sectionType {
        case .videoInfo:
            break
        case .actions:
            if indexPath.row == 0 {
                changeVideoTapped()
            } else {
                replaceButtonTapped()
            }
        case .tools:
            if indexPath.row == 0 {
                diagnosticTapped()
            } else {
                clearCacheTapped()
            }
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }

        let itemProvider = result.itemProvider

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            if let assetIdentifier = result.assetIdentifier {
                viewModel.selectVideo(assetID: assetIdentifier)
                tableView.reloadData()
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

        guard url.startAccessingSecurityScopedResource() else {
            print("❌ [Files] 无法访问安全范围资源")
            showAlert(title: "错误", message: "无法访问选择的文件")
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ [Files] 文件不存在")
            showAlert(title: "错误", message: "选择的文件不存在")
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            viewModel.selectVideoFromFile(url: url, fileName: url.lastPathComponent, fileSize: fileSize)
            tableView.reloadData()

            print("✅ [Files] 文件选择成功")

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
