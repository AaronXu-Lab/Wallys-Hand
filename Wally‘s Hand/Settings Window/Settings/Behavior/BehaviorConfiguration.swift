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
    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize


    var body: some View {
        SettingsForm {
            windowSection
            windowSnappingSection
            stageManagerSection
        }
        .animation(
            luminareAnimation,
            value: [
                windowSnapping,
                respectStageManager
            ]
        )
    }

    @ViewBuilder
    private var windowSection: some View {
        if !useSystemWindowManagerWhenAvailable {
            SettingsSection(String(localized: "Window", comment: "Section header shown in settings")) {
                SettingsToggle("Restore window frame on drag", isOn: $restoreWindowFrameOnDrag)
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
