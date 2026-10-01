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
    @Default(.sideDependentTriggerKey) private var sideDependentTriggerKey
    @Default(.triggerDelay) private var triggerDelay
    @Default(.cycleModeRestartEnabled) private var cycleModeRestartEnabled
    @Default(.cycleBackwardsOnShiftPressed) private var cycleBackwardsOnShiftPressed
    @Default(.doubleClickToTrigger) private var doubleClickToTrigger
    @Default(.keybinds) private var keybinds

    /// Is there at least one keybind action that is a cycle?
    private var isCycleActionPresentInKeybinds: Bool {
        keybinds.contains(where: { $0.cycle != nil })
    }

    /// Is Shift used in the trigger key?
    private var isShiftUsedByTriggerKey: Bool {
        triggerKey.map(\.baseModifier).contains(.kVK_Shift)
    }

    private var showCycleRestartOption: Bool {
        isCycleActionPresentInKeybinds
    }

    private var showCycleBackwardsOption: Bool {
        isCycleActionPresentInKeybinds && !isShiftUsedByTriggerKey
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
                showCycleBackwardsOption
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

    private var settingsSection: some View {
        Group {
            SettingsSection(String(localized: "Settings", comment: "Section header shown in settings")) {
                SettingsToggle("Treat left and right keys differently", isOn: $sideDependentTriggerKey)

                SettingsNumericField(
                    "Trigger delay",
                    value: $triggerDelay,
                    in: 0...1,
                    step: 0.1,
                    format: .number.precision(.fractionLength(1...1)),
                    clampsUpper: false,
                    suffix: Text("s", comment: "Unit symbol: seconds")
                )

                SettingsToggle("Double-click to trigger", isOn: $doubleClickToTrigger)
            }

            if showCycleRestartOption || showCycleBackwardsOption {
                SettingsSection(String(localized: "Cycles", comment: "Section header shown in settings")) {
                    if showCycleRestartOption {
                        SettingsToggle(isOn: $cycleModeRestartEnabled) {
                            Text("Always start cycles from first item")
                                .padding(.trailing, 4)
                                .settingsHelp() {
                                    Text("By default, Wally‘s Hand resumes cycles from where you last left off in each window.")
                                        .padding(6)
                                }
                        }
                    }

                    if showCycleBackwardsOption {
                        SettingsToggle("Cycle backward with Shift", isOn: $cycleBackwardsOnShiftPressed)
                    }
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
