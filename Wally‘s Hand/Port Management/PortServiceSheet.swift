import AaronUI
import AppKit
import SwiftUI

/// One destination for configuration, recovery policy, and diagnostics.
struct PortServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: PortServiceManager
    @State private var draft: PortService
    @State private var portText: String
    @State private var error: String?
    @State private var confirmingDeletion = false

    init(service: PortService, manager: PortServiceManager) {
        self.manager = manager
        _draft = State(initialValue: service)
        _portText = State(initialValue: String(service.port))
    }

    private var current: PortService? { manager.services.first { $0.id == draft.id } }
    private var status: PortServiceStatus { manager.status(draft.id) }
    private var isNew: Bool { current == nil }
    private var canSave: Bool {
        !status.protected && [draft.name, draft.directory, draft.command].allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } && Int(portText).map { (1...65535).contains($0) } == true
    }
    private var hasChanges: Bool {
        guard let current else { return true }
        return draft.name != current.name || portText != String(current.port)
            || draft.directory != current.directory || draft.command != current.command
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(current?.name ?? "添加服务")
                    .auiText(.headlineLg)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let current {
                    PortStatusBadge(status: status)
                    Button("查看日志", systemImage: "doc.text") { NSWorkspace.shared.open(current.logURL) }
                        .buttonStyle(AUIButtonStyle(variant: .ghost, size: .xs, contentType: .icon))
                        .help("查看日志")
                        .disabled(!FileManager.default.fileExists(atPath: current.logURL.path))
                }
            }
            .padding(AUISpacing.xxl)

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let current, status.protected || !status.detail.isEmpty {
                        runtimeSection(current)
                    }
                    configurationSection
                    recoverySection
                    monitoringSection
                    if let message = error ?? manager.storageError {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(AUIColor.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .padding(AUISpacing.xxl)
            }
            .frame(maxHeight: 450)
            Divider()
            footer
                .padding(AUISpacing.xxl)
        }
        .frame(width: 540)
        .background(SettingsAppearance.surface)
        .foregroundStyle(SettingsAppearance.ink)
        .tint(SettingsAppearance.accent)
        .alert("删除服务配置？", isPresented: $confirmingDeletion) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                guard let current else { return }
                error = manager.remove(current)
                if error == nil { dismiss() }
            }
        } message: {
            Text("将移除“\(current?.name ?? draft.name)”的配置，项目文件不受影响。")
        }
    }

    private func runtimeSection(_ service: PortService) -> some View {
        VStack(alignment: .leading, spacing: AUISpacing.lg) {
            if !status.detail.isEmpty {
                Text(status.detail)
                    .auiText(.bodySm)
                    .foregroundStyle(status.needsAttention ? AUIColor.warningInk : SettingsAppearance.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            HStack(spacing: AUISpacing.md) {
                if status.protected {
                    PortPrimaryAction(service: service, manager: manager)
                    if [.running, .starting, .interrupted, .retrying].contains(status.phase) {
                        Button("重新启动") { manager.retry(service.id) }
                            .buttonStyle(AUIButtonStyle(variant: .outline, size: .xs))
                    } else if status.phase != .stopped {
                        Button("停止服务") { manager.stop(service.id) }
                            .buttonStyle(AUIButtonStyle(variant: .outline, size: .xs))
                    }
                    Button("停用保护") { manager.disable(service.id) }
                        .buttonStyle(AUIButtonStyle(variant: .outline, size: .xs))
                }
                Spacer(minLength: 0)
            }
            if status.protected {
                Text("停止服务会保留占位页面；停用保护会停止服务并释放端口。")
                    .auiText(.caption)
                    .foregroundStyle(SettingsAppearance.muted)
            }
        }
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: AUISpacing.xl) {
            Text("配置").auiText(.headlineSm)
            if status.protected, let current {
                Text("停用保护后可修改配置。")
                    .auiText(.bodySm).foregroundStyle(SettingsAppearance.muted)
                LabeledContent("端口", value: String(current.port))
                readOnlyField("项目目录", value: current.directory)
                readOnlyField("启动命令", value: current.command)
            } else {
                HStack(alignment: .top, spacing: AUISpacing.lg) {
                    AUIInput("例如：网站开发", text: $draft.name, size: .sm, label: "名称")
                        .accessibilityLabel("名称")
                    AUIInput("5173", text: $portText, size: .sm, label: "端口", description: "1–65535")
                        .accessibilityLabel("端口")
                        .accessibilityHint("范围为 1 至 65535")
                        .frame(width: 120)
                }
                AUIInput("项目文件夹路径", text: $draft.directory, size: .sm, label: "项目目录") {
                    Button("选择…", action: chooseDirectory)
                        .buttonStyle(AUIButtonStyle(variant: .ghost, size: .xs))
                }
                AUIInputArea("例如：npm run dev -- --port 5173", text: $draft.command,
                             label: "启动命令", lines: 3...6)
                    .accessibilityLabel("启动命令")
                Text("使用登录 zsh 在项目目录运行，并提供 PORT 环境变量。命令须在前台运行，且使用指定端口。")
                    .auiText(.caption).foregroundStyle(SettingsAppearance.muted)
            }
        }
    }

    private func readOnlyField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AUISpacing.sm) {
            Text(title).auiText(.caption).foregroundStyle(SettingsAppearance.muted)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: AUISpacing.md) {
            Toggle(isOn: Binding(
                get: { current?.automaticallyRecover ?? draft.automaticallyRecover },
                set: { enabled in
                    if let current { error = manager.setAutomaticallyRecover(enabled, for: current.id) }
                    else { draft.automaticallyRecover = enabled }
                }
            )) {
                Text("自动恢复").auiText(.headlineSm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.auiSwitch)
            Text("异常断开后等待 3 秒，最多重试 10 次；手动停止后不会自动重启。")
                .auiText(.caption).foregroundStyle(SettingsAppearance.muted)
            if !isNew {
                Text("更改立即生效，无需保存。")
                    .auiText(.caption).foregroundStyle(SettingsAppearance.muted)
            }
        }
    }

    private var monitoringSection: some View {
        VStack(alignment: .leading, spacing: AUISpacing.md) {
            Toggle(isOn: Binding(
                get: { current?.isMonitoringLogs ?? draft.isMonitoringLogs },
                set: { enabled in
                    if let current { error = manager.setMonitorLogs(enabled, for: current.id) }
                    else { draft.monitorLogs = enabled }
                }
            )) {
                Text("监听日志").auiText(.headlineSm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.auiSwitch)
            Text("持续追加服务输出、状态变化和重试记录；关闭后下次启动恢复为只保留最近一次输出。")
                .auiText(.caption).foregroundStyle(SettingsAppearance.muted)
            if !isNew {
                Text("更改立即生效。日志位于 ~/Library/Logs/WallysHand/Ports/。")
                    .auiText(.caption).foregroundStyle(SettingsAppearance.muted)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: AUISpacing.md) {
            if !isNew && !status.protected {
                Button("删除服务", role: .destructive) { confirmingDeletion = true }
                    .buttonStyle(.borderless)
                    .foregroundStyle(AUIColor.error)
            }
            Spacer()
            Button(isNew || hasChanges ? "取消" : "完成") { dismiss() }
                .buttonStyle(AUIButtonStyle(variant: .outline, size: .xs))
                .keyboardShortcut(.cancelAction)
            if !status.protected {
                Button(isNew ? "添加服务" : "保存配置", action: save)
                    .buttonStyle(AUIButtonStyle(variant: .fill, size: .xs))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave || !hasChanges)
            }
        }
    }

    private func save() {
        guard let port = Int(portText) else { return }
        var updated = draft
        updated.port = port
        // The recovery switch applies immediately for existing services; do not overwrite it with a stale draft.
        updated.automaticallyRecover = current?.automaticallyRecover ?? draft.automaticallyRecover
        updated.monitorLogs = current?.monitorLogs ?? draft.monitorLogs
        error = manager.save(updated)
        if error == nil { dismiss() }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { draft.directory = url.path }
    }
}
