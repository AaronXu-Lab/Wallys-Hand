import AaronUI
import SwiftUI

struct PortConfigurationView: View {
    @ObservedObject private var manager = PortServiceManager.shared
    @State private var selectedService: PortService?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AUISpacing.lg) {
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
    }

    private var addButton: some View {
        Button("添加服务", systemImage: "plus") { selectedService = PortService() }
            .buttonStyle(AUIButtonStyle(variant: .fill, size: .xs, contentType: .iconText))
    }
}
