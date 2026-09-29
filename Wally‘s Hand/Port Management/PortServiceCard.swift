import AaronUI
import SwiftUI

/// The overview answers only: which service, which port, what state, and what next.
struct PortServiceCard: View {
    let service: PortService
    @ObservedObject var manager: PortServiceManager
    let showDetails: () -> Void

    private var status: PortServiceStatus { manager.status(service.id) }

    var body: some View {
        HStack(spacing: AUISpacing.xl) {
            VStack(alignment: .leading, spacing: AUISpacing.md) {
                Text(service.name)
                    .auiText(.headlineSm)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: AUISpacing.md) {
                    Text(":\(String(service.port))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(SettingsAppearance.muted)
                        .accessibilityLabel("端口 \(String(service.port))")
                    PortStatusBadge(status: status)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AUISpacing.md) {
                PortPrimaryAction(service: service, manager: manager)
                Button("详情", action: showDetails)
                    .buttonStyle(AUIButtonStyle(variant: .ghost, size: .xs))
                    .accessibilityLabel("\(service.name) 的详情与配置")
            }
            .fixedSize()
        }
        .padding(AUISpacing.xl)
        .background(SettingsAppearance.surface, in: RoundedRectangle(cornerRadius: AUIRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AUIRadius.lg)
                .strokeBorder(status.needsAttention ? AUIColor.warning.opacity(0.45) : SettingsAppearance.line)
        }
    }
}

struct PortPrimaryAction: View {
    let service: PortService
    @ObservedObject var manager: PortServiceManager
    private var status: PortServiceStatus { manager.status(service.id) }
    private var shouldStop: Bool {
        status.protected && [.running, .starting, .interrupted, .retrying].contains(status.phase)
    }
    private var title: String {
        if !status.protected { return "启用保护" }
        if shouldStop { return "停止服务" }
        return status.phase == .stopped ? "启动服务" : "重试"
    }

    var body: some View {
        Button(title) {
            if !status.protected { manager.enable(service) }
            else if shouldStop { manager.stop(service.id) }
            else { manager.retry(service.id) }
        }
        .buttonStyle(AUIButtonStyle(variant: .outline, size: .xs))
        .help(shouldStop ? "停止服务，保留端口保护和占位页面。" : "启动服务并保护端口。")
        .accessibilityLabel("\(service.name)：\(title)")
    }
}

struct PortStatusBadge: View {
    let status: PortServiceStatus

    private var color: AUIBadgeColor {
        switch status.phase {
        case .running: .green
        case .failed, .conflict: .red
        case .starting, .interrupted, .retrying: .blue
        case .stopped, .disabled: .primary
        }
    }

    private var symbol: String {
        switch status.phase {
        case .running: "checkmark.circle"
        case .starting, .interrupted, .retrying: "clock"
        case .failed, .conflict: "exclamationmark.triangle"
        case .stopped: "pause.circle"
        case .disabled: "circle"
        }
    }

    var body: some View {
        AUIBadge(status.phase.rawValue, systemImage: symbol,
                 size: .sm, variant: .light, color: color)
    }
}
