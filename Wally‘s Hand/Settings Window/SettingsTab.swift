//
//  SettingsTab.swift
//  Loop
//
//  Created by Kai Azim on 2025-12-05.
//

import AppKit
import Luminare
import SwiftUI

@MainActor
enum SettingsTab: @MainActor LuminareTabItem, CaseIterable {
    var id: String { title }

    case behavior
    case keybinds

    case ports
    case advanced
    case excludedApps
    case about

    var icon: some View {
        SettingsTabIconView(tab: self)
    }

    var color: Color { SettingsAppearance.accent }

    var title: String {
        switch self {
        case .behavior: .init(localized: "Settings tab: Behavior", defaultValue: "Behavior")
        case .keybinds: .init(localized: "Settings tab: Keybindings", defaultValue: "Keybinds")
        case .ports: "端口管理"
        case .advanced: .init(localized: "Settings tab: Advanced", defaultValue: "Advanced")
        case .excludedApps: .init(localized: "Settings tab: Excluded Apps", defaultValue: "Excluded Apps")
        case .about: .init(localized: "Settings tab: About", defaultValue: "About")
        }
    }

    var subtitle: String {
        switch self {
        case .keybinds:
            String(localized: "Assign shortcuts to window layouts and cycles.")
        case .behavior:
            String(localized: "Choose how windows respond to your actions.")
        case .ports:
            "配置项目启动命令，保护端口并管理服务恢复。"
        case .advanced:
            String(localized: "Fine-tune window controls and manage your shortcuts.")
        case .excludedApps:
            String(localized: "Keep selected apps out of window controls.")
        case .about:
            String(localized: "Version, updates, and project information.")
        }
    }

    var image: Image {
        switch self {
        case .behavior: Image(systemName: "gearshape.fill")
        case .keybinds: Image(systemName: "keyboard.fill")
        case .ports: Image(systemName: "network")
        case .advanced: Image(systemName: "wrench.adjustable.fill")
        case .excludedApps: Image(systemName: "xmark.octagon.fill")
        case .about: Image(systemName: "info.circle.fill")
        }
    }

    var showIndicator: Bool {
        switch self {
        case .about: Updater.shared.updateState == .available
        default: false
        }
    }

    @ViewBuilder func view() -> some View {
        switch self {
        case .behavior: BehaviorConfigurationView()
        case .keybinds: KeybindsConfigurationView()
        case .ports: PortConfigurationView()
        case .advanced: AdvancedConfigurationView()
        case .excludedApps: ExcludedAppsConfigurationView()
        case .about: AboutConfigurationView()
        }
    }

    static let allTabs: [Self] = [.keybinds, .behavior, .ports, .advanced, .excludedApps, .about]
}

struct SettingsTabIconView: View {
    let tab: SettingsTab

    var body: some View {
        tab.image
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(SettingsAppearance.accent)
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }
}
