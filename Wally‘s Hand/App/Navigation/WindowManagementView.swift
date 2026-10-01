import AaronUI
import Defaults
import SwiftUI

struct WindowManagementView: View {
    @Binding var selection: WindowToolTab
    @Default(.windowManagementEnabled) private var enabled

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AUISpacing.lg) {
                SettingsToggle("启用窗口管理", isOn: Binding(
                    get: { enabled },
                    set: { value in
                        if value { AccessibilityManager.requestAccess() }
                        enabled = value
                    }
                ))
                if !enabled {
                    Text("当前未启用，仍可编辑配置。启用后需要辅助功能权限。")
                        .auiText(.caption)
                        .foregroundStyle(SettingsAppearance.muted)
                }
                AUISegmented(selection: $selection,
                             items: WindowToolTab.allCases.map { .init($0.title, value: $0) },
                             size: .sm, width: .fill)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("窗口管理分类")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AUISpacing.xxl)
            selection.content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
