import SwiftUI

/// Only independent tools and application-wide destinations belong in the main sidebar.
enum AppDestination: String, CaseIterable, Identifiable {
    case windows, ports, settings, about

    var id: Self { self }
    var isTool: Bool { self == .windows || self == .ports }
    static let tools: [Self] = [.windows, .ports]
    static let application: [Self] = [.settings, .about]

    var title: String {
        switch self {
        case .windows: String(localized: "窗口管理")
        case .ports: String(localized: "端口管理")
        case .settings: String(localized: "通用设置")
        case .about: String(localized: "关于")
        }
    }

    var subtitle: String {
        switch self {
        case .windows: String(localized: "用快捷键和边缘吸附整理窗口。")
        case .ports: String(localized: "配置项目启动命令，保护端口并管理服务恢复。")
        case .settings: String(localized: "语言、启动方式与应用显示。")
        case .about: String(localized: "版本、更新与项目信息。")
        }
    }

    var symbol: String {
        switch self {
        case .windows: "rectangle.split.2x2"
        case .ports: "network"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}

/// Window-management preferences are local navigation, never peers of other tools.
enum WindowToolTab: String, CaseIterable, Identifiable {
    case keybinds, behavior, excludedApps, advanced
    var id: Self { self }
    var title: String {
        switch self {
        case .keybinds: String(localized: "快捷键")
        case .behavior: String(localized: "窗口行为")
        case .excludedApps: String(localized: "排除应用")
        case .advanced: String(localized: "高级")
        }
    }

    @MainActor @ViewBuilder var content: some View {
        switch self {
        case .keybinds: KeybindsConfigurationView()
        case .behavior: BehaviorConfigurationView()
        case .excludedApps: ExcludedAppsConfigurationView()
        case .advanced: AdvancedConfigurationView()
        }
    }
}
