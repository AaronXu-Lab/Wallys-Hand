import AaronUI
import Defaults
import SwiftUI

/// Application preferences apply across every tool, independently of window management.
struct GeneralConfigurationView: View {
    @AppStorage("PreferredAppLanguage") private var preferredAppLanguage = ""
    @ObservedObject private var ports = PortServiceManager.shared
    @State private var quickStartError: String?
    @State private var showRestartNotice = false
    @Default(.launchAtLogin) private var launchAtLogin
    @Default(.startHidden) private var startHidden
    @Default(.hideMenuBarIcon) private var hideMenuBarIcon

    var body: some View {
        SettingsForm {
            generalSection
            quickStartSection
        }
    }

    private var quickStartSection: some View {
        SettingsSection("快速启动") {
            Text("选择点击“快速启动”时要启动的服务。更改立即保存，不会启动服务；默认不选择任何服务。")
                .auiText(.bodySm)
                .foregroundStyle(SettingsAppearance.muted)
            if ports.services.isEmpty {
                Text("请先在端口管理中添加服务。")
                    .auiText(.bodySm)
                    .foregroundStyle(SettingsAppearance.muted)
            }
            ForEach(ports.services) { service in
                SettingsToggle(isOn: Binding(
                    get: { ports.services.first(where: { $0.id == service.id })?.quickStart == true },
                    set: { quickStartError = ports.setQuickStart($0, for: service.id) }
                )) {
                    Text("\(service.name) · :\(String(service.port))").auiText(.bodyMd)
                }
            }
            if let message = quickStartError ?? ports.storageError {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(AUIColor.error)
            }
        }
    }

    private var generalSection: some View {
        SettingsSection(String(localized: "General", comment: "Section header shown in settings")) {
            AUIDropdown(
                selection: Binding<String?>(
                    get: {
                        if !preferredAppLanguage.isEmpty {
                            return preferredAppLanguage
                        }
                        return Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
                    },
                    set: { language in
                        guard let language else { return }
                        preferredAppLanguage = language
                        UserDefaults.standard.set([language], forKey: "AppleLanguages")
                        showRestartNotice = true
                    }
                ),
                items: [.init("English", value: "en"), .init("中文", value: "zh-Hans")],
                size: .sm,
                label: String(localized: "Language"),
                accessibilityLabel: String(localized: "Language")
            )
            .auiSheet(
                isPresented: $showRestartNotice,
                title: String(localized: "Restart to Apply Language"),
                width: .sm,
                showClose: false
            ) {
                Text("Quit and launch Wally‘s Hand again to use the selected language.").auiText(.bodyMd)
            } actions: {
                AUIButton(String(localized: "OK"), variant: .fill, size: .sm) { showRestartNotice = false }
                    .keyboardShortcut(.defaultAction)
            }

            SettingsToggle("Launch at login", isOn: $launchAtLogin)

            SettingsToggle("Start hidden", isOn: $startHidden)

            SettingsToggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
        }
    }
}
