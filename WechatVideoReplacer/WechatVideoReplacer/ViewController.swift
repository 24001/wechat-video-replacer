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
 * 功能描述: 主视图控制器 - iOS 原生 UITableView 设计
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
        table.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0) // 对齐图标后的文本

        // 注册自定义 Cell
        table.register(VideoInfoCell.self, forCellReuseIdentifier: "VideoInfoCell")
        table.register(ActionButtonCell.self, forCellReuseIdentifier: "ActionButtonCell")
        table.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")

        return table
    }()

    // MARK: - 属性

    private let viewModel = VideoViewModel()
    private var isExecuting = false

    // 表格数据源枚举
    private enum Section: Int, CaseIterable {
        case videoInfo    // 素材信息
        case actions      // 操作按钮
        case tools        // 工具按钮

        var title: String {
            switch self {
            case .videoInfo: return "当前素材"
            case .actions: return "操作"
            case .tools: return "工具"
            }
        }

        var footer: String? {
            switch self {
            case .videoInfo: return nil
            case .actions: return "请确保已在微信中录制视频草稿后再执行替换"
            case .tools: return "系统诊断可帮助排查权限问题"
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
        title = "微信视频替换工具"
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
                // 状态更新时刷新表格
                self?.tableView.reloadSections(IndexSet(integer: Section.actions.rawValue), with: .none)
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
        let alert = UIAlertController(title: "选择视频来源", message: "请选择视频的来源", preferredStyle: .actionSheet)

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

        let alert = UIAlertController(title: "系统诊断", message: message, preferredStyle: .alert)

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
        tableView.reloadSections(IndexSet(integer: Section.actions.rawValue), with: .none)

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
            title: "✅ 替换成功",
            message: "素材已成功替换！\n\n现在请:\n1. 打开微信\n2. 进入发布页面\n3. 查看视频是否已替换\n4. 点击发布",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "太好了！", style: .default))
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
            return 1  // 素材信息卡片
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

        switch sectionType {
        case .videoInfo:
            return configureVideoInfoCell(tableView, indexPath: indexPath)
        case .actions:
            return configureActionCell(tableView, indexPath: indexPath)
        case .tools:
            return configureToolCell(tableView, indexPath: indexPath)
        }
    }

    // 配置素材信息 Cell
    private func configureVideoInfoCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoInfoCell", for: indexPath) as! VideoInfoCell
        cell.configure(with: viewModel.savedVideo)
        return cell
    }

    // 配置操作按钮 Cell
    private func configureActionCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionButtonCell", for: indexPath) as! ActionButtonCell

        if indexPath.row == 0 {
            // 更换素材按钮
            cell.configure(
                title: "更换素材",
                icon: "arrow.triangle.2.circlepath",
                color: .systemBlue,
                enabled: !isExecuting
            ) { [weak self] in
                self?.changeVideoTapped()
            }
        } else {
            // 一键替换按钮
            let hasVideo = viewModel.savedVideo != nil
            let title = isExecuting ? "执行中..." : "一键替换"
            let icon = isExecuting ? "hourglass" : "play.fill"

            cell.configure(
                title: title,
                icon: icon,
                color: .systemGreen,
                enabled: hasVideo && !isExecuting,
                highlighted: hasVideo
            ) { [weak self] in
                self?.replaceButtonTapped()
            }
        }

        return cell
    }

    // 配置工具按钮 Cell
    private func configureToolCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        var content = cell.defaultContentConfiguration()

        if indexPath.row == 0 {
            // 系统诊断
            content.text = "系统诊断"
            content.secondaryText = "检查权限和路径配置"
            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: "stethoscope")
            }
            content.imageProperties.tintColor = .systemGray
        } else {
            // 清除缓存
            content.text = "清除缓存"
            content.secondaryText = "清空素材和路径缓存"
            if #available(iOS 13.0, *) {
                content.image = UIImage(systemName: "trash")
            }
            content.imageProperties.tintColor = .systemRed
        }

        cell.contentConfiguration = content
        return cell
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

        // 只有工具部分响应点击
        if sectionType == .tools {
            if indexPath.row == 0 {
                diagnosticTapped()
            } else {
                clearCacheTapped()
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableView.automaticDimension
        }

        switch sectionType {
        case .videoInfo:
            return UITableView.automaticDimension
        case .actions:
            return 60  // 操作按钮高度
        case .tools:
            return UITableView.automaticDimension
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
            // 获取 PHAsset
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
            tableView.reloadData()

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

// MARK: - 自定义 Cell 类

/// 素材信息展示 Cell
class VideoInfoCell: UITableViewCell {

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        if #available(iOS 13.0, *) {
            imageView.image = UIImage(systemName: "video.fill")
        }
        imageView.tintColor = .systemGray
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 28),
            iconImageView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with video: SavedVideo?) {
        if let video = video {
            titleLabel.text = video.fileName
            titleLabel.textColor = .label
            detailLabel.text = "\(video.formattedFileSize()) | \(video.formattedDuration())"
            iconImageView.tintColor = .systemBlue
        } else {
            titleLabel.text = "未选择素材"
            titleLabel.textColor = .secondaryLabel
            detailLabel.text = "点击"更换素材"选择视频"
            iconImageView.tintColor = .systemGray
        }
    }
}

/// 操作按钮 Cell
class ActionButtonCell: UITableViewCell {

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var action: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGesture)
    }

    @objc private func cellTapped() {
        action?()
    }

    func configure(
        title: String,
        icon: String,
        color: UIColor,
        enabled: Bool = true,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) {
        self.action = action

        titleLabel.text = title
        titleLabel.textColor = enabled ? color : .systemGray3

        if #available(iOS 13.0, *) {
            iconImageView.image = UIImage(systemName: icon)
        }
        iconImageView.tintColor = enabled ? color : .systemGray3

        contentView.isUserInteractionEnabled = enabled
        contentView.alpha = enabled ? 1.0 : 0.5

        // 高亮样式（一键替换按钮）
        if highlighted {
            backgroundColor = enabled ? color.withAlphaComponent(0.1) : .systemGray6
        } else {
            backgroundColor = .systemBackground
        }
    }
}
