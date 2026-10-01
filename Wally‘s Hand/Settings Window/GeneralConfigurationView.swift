import Defaults
import AaronUI
import SwiftUI

/// Application preferences apply across every tool, independently of window management.
struct GeneralConfigurationView: View {
    @AppStorage("PreferredAppLanguage") private var preferredAppLanguage = ""
    @State private var showRestartNotice = false
    @Default(.launchAtLogin) private var launchAtLogin
    @Default(.startHidden) private var startHidden
    @Default(.hideMenuBarIcon) private var hideMenuBarIcon

    var body: some View {
        SettingsForm { generalSection }
    }

    private var generalSection: some View {
        SettingsSection(String(localized: "General", comment: "Section header shown in settings")) {
            AUIDropdown(selection: Binding<String?>(
                get: {
                    if !preferredAppLanguage.isEmpty { return preferredAppLanguage }
                    return Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
                },
                set: { language in
                    guard let language else { return }
                    preferredAppLanguage = language
                    UserDefaults.standard.set([language], forKey: "AppleLanguages")
                    showRestartNotice = true
                }
            ), items: [.init("English", value: "en"), .init("中文", value: "zh-Hans")],
            size: .sm, label: String(localized: "Language"), accessibilityLabel: String(localized: "Language"))
            .auiSheet(isPresented: $showRestartNotice, title: String(localized: "Restart to Apply Language"),
                      width: .sm, showClose: false) {
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
