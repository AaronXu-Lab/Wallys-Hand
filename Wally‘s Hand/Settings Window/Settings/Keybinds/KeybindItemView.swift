//
//  KeybindItemView.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-03.
//

import Defaults
import AaronUI
import SwiftUI

struct KeybindItemView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var luminareAnimation: Animation { reduceMotion ? .linear(duration: 0) : AUIMotion.fast }

    @Default(.triggerKey) private var triggerKey
    @Default(.keybinds) private var keybinds

    @State private var action: WindowAction
    @Binding private var boundAction: WindowAction

    @State private var isConfiguringCustom: Bool = false
    @State private var isConfiguringCycle: Bool = false
    private let cycleIndex: Int?
    @State private var isDirectionPickerPresented = false

    init(_ action: Binding<WindowAction>, cycleIndex: Int? = nil) {
        self.action = action.wrappedValue
        self._boundAction = action
        self.cycleIndex = cycleIndex
    }

    /// Checks if there are any existing keybinds with the same key combination
    private var hasDuplicateKeybinds: Bool {
        guard !action.keybind.isEmpty else {
            return false
        }

        let effectiveKeybind = action.bypassTriggerKey == true
            ? action.keybind
            : triggerKey.union(action.keybind)

        return keybinds.contains { otherAction in
            guard otherAction.id != action.id else { return false }
            let otherEffectiveKeybind = otherAction.bypassTriggerKey == true
                ? otherAction.keybind
                : triggerKey.union(otherAction.keybind)
            return effectiveKeybind == otherEffectiveKeybind
        }
    }

    var body: some View {
        HStack(spacing: AUISpacing.md) {
            titleAndButtons
            Spacer(minLength: 0)
            keybindCombination.fixedSize().layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .onChange(of: action.direction) { _ in
            if action.direction.isCustomizable {
                isConfiguringCustom = true
            }
            if action.direction == .cycle {
                isConfiguringCycle = true
            }
        }
        .onChange(of: action) { boundAction = $0 }
    }

    private var titleAndButtons: some View {
        HStack(spacing: 2) {
            label()

            Group {
                if action.direction.isCustomizable {
                    Button {
                        isConfiguringCustom = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(AUIButtonStyle(variant: .ghost, size: .xs))
                    .settingsSheet(isPresented: $isConfiguringCustom, title: String(localized: "Custom Action"), width: .sm) {
                        CustomActionConfigurationView(
                            action: $action,
                            isPresented: $isConfiguringCustom
                        )
                        .frame(width: 400)
                    }
                    .accessibilityLabel("Customize this action's custom frame.")
                    .help("Customize this action's custom frame.")
                }

                if action.direction == .cycle {
                    Button {
                        isConfiguringCycle = true
                    } label: {
                        Image(systemName: "repeat")
                    }
                    .buttonStyle(AUIButtonStyle(variant: .ghost, size: .xs))
                    .settingsSheet(isPresented: $isConfiguringCycle, title: String(localized: "Cycle Keybind"), width: .sm) {
                        CycleActionConfigurationView(
                            action: $action,
                            isPresented: $isConfiguringCycle
                        )
                        .frame(width: 400)
                    }
                    .accessibilityLabel("Customize what this action cycles through.")
                    .help("Customize what this action cycles through.")
                }
            }
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .background(alignment: .leading) {
            Color.clear
                .frame(width: 300 - 24)
                .popover(isPresented: $isDirectionPickerPresented, arrowEdge: .top) {
                    DirectionPickerView(
                        direction: $action.direction,
                        isInCycle: cycleIndex != nil
                    )
                    .frame(width: 300, height: 300)
                }
                .onChange(of: isDirectionPickerPresented) { _ in
                    if !isDirectionPickerPresented {
                        PickerListEventMonitorManager.shared.removeAllMonitors()
                    }
                }
        }
    }

    private var keybindCombination: some View {
        HStack {
            if let cycleIndex {
                Text("\(cycleIndex)")
                    .frame(width: 27, height: 27)
                    .background(AUIColor.surfaceControl, in: RoundedRectangle(cornerRadius: AUIRadius.sm))
            } else {
                HStack(spacing: 6) {
                    keycorderSection()
                        .padding(.leading, 4)
                        .settingsHelp(hidden: !hasDuplicateKeybinds) {
                            Text("There are other keybinds that conflict with this key combination.")
                                .padding(6)
                        }
                }
                .fixedSize()
            }
        }
    }

    // MARK: - Helper Methods

    /// Switches to standard mode (keeps the keybind)
    private func restoreStandardMode() {
        action.keybind = action.keybind.subtracting(triggerKey)
        action.bypassTriggerKey = false
    }

    /// Merges trigger key into action key and switches to bypass mode
    private func switchToBypassMode() {
        action.keybind = triggerKey.union(action.keybind)
        action.bypassTriggerKey = true
    }

    /// Clears the keybind and switches to standard mode
    private func clearKeybind() {
        action.keybind = []
        action.bypassTriggerKey = false
    }

    private func label() -> some View {
        Button {
            isDirectionPickerPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                IconView(action: action)

                if let info = action.direction.infoText {
                    Text(action.getName())
                        .fontWeight(.regular)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                        .settingsHelp() {
                            Text(info)
                                .padding(6)
                        }
                } else {
                    Text(action.getName())
                        .fontWeight(.regular)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }


        .help("Customize this keybind's action.")
        .padding(.leading, -4)
    }

    private func keycorderSection() -> some View {
        HStack(spacing: 6) {
            if action.bypassTriggerKey != true {
                HStack(spacing: 6) {
                    ForEach(triggerKey.sorted().compactMap(\.modifierSystemImage), id: \.self) { image in
                        Text("\(Image(systemName: image))")
                    }
                }
                .font(.callout)
                .padding(6)
                .frame(height: 27)
                .background(AUIColor.surfaceControl, in: RoundedRectangle(cornerRadius: AUIRadius.sm))

                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }

            Keycorder($action)
                .opacity(hasDuplicateKeybinds || action.keybind.isEmpty ? 0.5 : 1)
        }
        .contextMenu {
            if action.bypassTriggerKey == true {
                Button("Link Trigger Key", action: restoreStandardMode)
            } else {
                Button("Unlink Trigger Key", action: switchToBypassMode)
            }

            Button("Clear Keybind", action: clearKeybind)
        }
    }
}
