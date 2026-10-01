import AaronUI
import SwiftUI
import UniformTypeIdentifiers

struct PortConfigurationView: View {
    @ObservedObject private var manager = PortServiceManager.shared
    @State private var selectedService: PortService?
    @State private var backupError: String?
    @State private var backupMessage: String?
    @State private var pendingImport: Data?
    @State private var confirmingImport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AUISpacing.lg) {
                HStack {
                    Text("服务配置备份")
                        .auiText(.bodySm)
                        .foregroundStyle(SettingsAppearance.muted)
                    Spacer()
                    Button("导入配置…", action: importBackup)
                    Button("导出全部配置…", action: exportBackup)
                        .disabled(manager.services.isEmpty || manager.storageError != nil)
                }
                if let backupError {
                    Label(backupError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AUIColor.error)
                        .textSelection(.enabled)
                } else if let backupMessage {
                    Label(backupMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(SettingsAppearance.muted)
                }
                if let message = manager.storageError {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AUIColor.error)
                        .textSelection(.enabled)
                }
                if manager.services.isEmpty {
                    AUIEmptyState("尚未添加服务", systemImage: "network",
                                  description: "添加项目和启动命令，集中管理本地服务。") {
                        addButton
                    }
                    .background(SettingsAppearance.surface, in: RoundedRectangle(cornerRadius: AUIRadius.lg))
                } else {
                    HStack {
                        Text("\(manager.services.count) 个服务")
                            .auiText(.bodySm)
                            .foregroundStyle(SettingsAppearance.muted)
                        Spacer()
                        addButton
                    }
                    .padding(.bottom, AUISpacing.xs)

                    ForEach(manager.services) { service in
                        PortServiceCard(service: service, manager: manager) {
                            selectedService = service
                        }
                    }
                }
            }
            .padding(AUISpacing.xxl)
        }
        .sheet(item: $selectedService) { service in
            PortServiceSheet(service: service, manager: manager)
        }
        .alert("替换全部端口配置？", isPresented: $confirmingImport) {
            Button("取消", role: .cancel) { pendingImport = nil }
            Button("替换", role: .destructive) {
                guard let pendingImport else { return }
                do {
                    try manager.importBackup(pendingImport)
                    backupError = nil
                    backupMessage = "已导入全部服务配置。服务保护需手动启用。"
                } catch {
                    backupError = error.localizedDescription
                    backupMessage = nil
                }
                self.pendingImport = nil
            }
        } message: {
            Text("现有服务配置将被备份文件替换。导入后不会自动启动服务。")
        }
    }

    private var addButton: some View {
        Button("添加服务", systemImage: "plus") { selectedService = PortService() }
            .buttonStyle(AUIButtonStyle(variant: .fill, size: .xs, contentType: .iconText))
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "导出全部端口配置"
        panel.nameFieldStringValue = "WallysHand-Ports.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try manager.exportBackup().write(to: url, options: .atomic)
            backupError = nil
            backupMessage = "已导出全部服务配置。"
        } catch {
            backupError = error.localizedDescription
            backupMessage = nil
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "导入端口配置"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            pendingImport = try Data(contentsOf: url)
            confirmingImport = true
        } catch {
            backupError = error.localizedDescription
            backupMessage = nil
        }
    }
}
