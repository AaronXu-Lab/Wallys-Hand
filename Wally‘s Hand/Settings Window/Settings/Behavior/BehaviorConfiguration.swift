//
//  BehaviorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import AaronUI
import SwiftUI

struct BehaviorConfigurationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var luminareAnimation: Animation { reduceMotion ? .linear(duration: 0) : AUIMotion.fast }
    @Default(.windowSnapping) var windowSnapping
    @Default(.suppressMissionControlOnTopDrag) var suppressMissionControlOnTopDrag
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.useSystemWindowManagerWhenAvailable) var useSystemWindowManagerWhenAvailable
    @Default(.useScreenWithCursor) var useScreenWithCursor
    @Default(.moveCursorWithWindow) var moveCursorWithWindow
    @Default(.resizeWindowUnderCursor) var resizeWindowUnderCursor
    @Default(.focusWindowOnResize) var focusWindowOnResize
    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize

    @State private var isPaddingConfigurationViewPresented = false

    var body: some View {
        SettingsForm {
            windowSection
            cursorSection
            windowSnappingSection
            stageManagerSection
        }
        .animation(
            luminareAnimation,
            value: [
                resizeWindowUnderCursor,
                windowSnapping,
                respectStageManager
            ]
        )
    }

    private var windowSection: some View {
        SettingsSection(String(localized: "Window", comment: "Section header shown in settings")) {
            SettingsToggle("Move window to cursor's screen", isOn: $useScreenWithCursor)

            // Enabling the system window manager will override these options.
            if !useSystemWindowManagerWhenAvailable {
                SettingsToggle("Restore window frame on drag", isOn: $restoreWindowFrameOnDrag)
                SettingsActionRow("Padding", "Configure…") {
                    isPaddingConfigurationViewPresented = true
                }
                .settingsSheet(isPresented: $isPaddingConfigurationViewPresented, title: String(localized: "Padding"), width: .sm) {
                    PaddingConfigurationView(isPresented: $isPaddingConfigurationViewPresented)
                        .frame(width: 400)
                }
            }
        }
    }

    private var cursorSection: some View {
        SettingsSection(String(localized: "Cursor", comment: "Section header shown in settings")) {
            SettingsToggle("Move cursor with window", isOn: $moveCursorWithWindow)

            SettingsToggle("Resize window under cursor", isOn: $resizeWindowUnderCursor)

            // If the system WM is enabled, the window under the cursor requires focus.
            if resizeWindowUnderCursor, !useSystemWindowManagerWhenAvailable {
                SettingsToggle("Focus window on resize", isOn: $focusWindowOnResize)
            }
        }
    }

    private var windowSnappingSection: some View {
        SettingsSection(String(localized: "Window Snapping", comment: "Section header shown in settings")) {
            if #available(macOS 15, *) {
                SettingsToggle(isOn: $windowSnapping) {
                    if SystemWindowManager.MoveAndResize.snappingEnabled {
                        Text("Enable window snapping")
                            .padding(.trailing, 4)
                            .settingsHelp() {
                                Text("macOS's \"Tile by dragging windows to screen edges\" feature is currently\nenabled, which will conflict with Wally‘s Hand's window snapping functionality.")
                                    .padding(6)
                            }
                    } else {
                        Text("Enable window snapping")
                    }
                }
            } else {
                SettingsToggle("Enable window snapping", isOn: $windowSnapping)
            }

            if windowSnapping {
                SettingsToggle("Suppress Mission Control", isOn: $suppressMissionControlOnTopDrag)
            }
        }
    }

    private var stageManagerSection: some View {
        SettingsSection(String(localized: "Stage Manager", comment: "Section header shown in settings")) {
            SettingsToggle("Respect Stage Manager", isOn: $respectStageManager)

            if respectStageManager {
                SettingsNumericField(
                    "Stage strip size",
                    value: $stageStripSize.doubleBinding,
                    in: 50...250,
                    step: 1,
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    suffix: Text("px", comment: "Unit symbol: pixels")
                )
            }
        }
    }
}
