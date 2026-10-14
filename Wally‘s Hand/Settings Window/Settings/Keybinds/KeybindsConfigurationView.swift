//
//  KeybindsConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-20.
//

import Defaults
import AaronUI
import SwiftUI

final class KeybindsConfigurationModel: ObservableObject {
    @Published var currentEventMonitor: LocalEventMonitor?
    @Published var selectedKeybinds = Set<WindowAction>()
}

struct KeybindsConfigurationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var luminareAnimation: Animation { reduceMotion ? .linear(duration: 0) : AUIMotion.fast }
    @StateObject private var model = KeybindsConfigurationModel()

    @Default(.triggerKey) private var triggerKey
    @Default(.cycleModeRestartEnabled) private var cycleModeRestartEnabled
    @Default(.keybinds) private var keybinds

    /// Is there at least one keybind action that is a cycle?
    private var isCycleActionPresentInKeybinds: Bool {
        keybinds.contains(where: { $0.cycle != nil })
    }

    var body: some View {
        SettingsForm {
            triggerKeySection
            keybindsSection
            settingsSection
        }
        .animation(
            luminareAnimation,
            value: [
                cycleModeRestartEnabled,
                isCycleActionPresentInKeybinds
            ]
        )
    }

    private var triggerKeySection: some View {
        SettingsSection(String(localized: "Trigger Key", comment: "Section header shown in settings")) {
            Text("Hold this key, then press an assigned shortcut to move a window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TriggerKeycorder($triggerKey)
                .environmentObject(model)
        }
    }

    @ViewBuilder
    private var settingsSection: some View {
        if isCycleActionPresentInKeybinds {
            SettingsSection(String(localized: "Cycles", comment: "Section header shown in settings")) {
                // This form owns a ScrollView rather than the List required by AUIItem.
                // Keep the switch's text label separate from its supporting description.
                HStack(spacing: AUISpacing.lg) {
                    VStack(alignment: .leading, spacing: AUISpacing.sm) {
                        Text("Always start cycles from first item")
                            .auiText(AUITextStyle.bodyMd.emphasized())
                        Text("By default, Wally‘s Hand resumes cycles from where you last left off in each window.")
                            .auiText(.bodySm)
                            .foregroundStyle(AUIColor.onSurfaceMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("Always start cycles from first item", isOn: $cycleModeRestartEnabled)
                        .labelsHidden()
                        .toggleStyle(.auiSwitch)
                }
            }
        }
    }

    private var keybindsSection: some View {
        SettingsSection(String(localized: "Keybinds", comment: "Section header shown in settings")) {
            SettingsActions {
                Button("Add") {
                    keybinds.insert(.init(.noAction), at: 0)
                }

                Button("Remove", role: .destructive) {
                    keybinds.removeAll(where: model.selectedKeybinds.contains)
                }
                .disabled(model.selectedKeybinds.isEmpty)
                .keyboardShortcut(.delete)
            }

            SettingsSelectionList(
                items: $keybinds,
                selection: $model.selectedKeybinds,
                id: \.id
            ) { keybind in
                KeybindItemView(keybind)
                    .environmentObject(model)
            } emptyView: {
                AUIEmptyState(String(localized: "No keybinds"), systemImage: "keyboard", type: .inline)
            }
        }
    }
}
