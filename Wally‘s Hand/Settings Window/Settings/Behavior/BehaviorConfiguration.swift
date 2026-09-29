//
//  BehaviorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

struct BehaviorConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @AppStorage("PreferredAppLanguage") private var preferredAppLanguage = ""
    @State private var showRestartNotice = false

    @Default(.launchAtLogin) var launchAtLogin
    @Default(.startHidden) var startHidden
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
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
        LuminareForm {
            generalSection
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

    private var generalSection: some View {
        LuminareSection(String(localized: "General", comment: "Section header shown in settings")) {
            Picker("Language", selection: Binding(
                get: {
                    if !preferredAppLanguage.isEmpty { return preferredAppLanguage }
                    return Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
                },
                set: { language in
                    preferredAppLanguage = language
                    UserDefaults.standard.set([language], forKey: "AppleLanguages")
                    showRestartNotice = true
                }
            )) {
                Text("English").tag("en")
                Text("中文").tag("zh-Hans")
            }
            .pickerStyle(.menu)
            .alert("Restart to Apply Language", isPresented: $showRestartNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Quit and launch Wally‘s Hand again to use the selected language.")
            }

            LuminareToggle("Launch at login", isOn: $launchAtLogin)

            LuminareToggle("Start hidden", isOn: $startHidden)

            LuminareToggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
        }
    }

    private var windowSection: some View {
        LuminareSection(String(localized: "Window", comment: "Section header shown in settings")) {
            LuminareToggle("Move window to cursor's screen", isOn: $useScreenWithCursor)

            // Enabling the system window manager will override these options.
            if !useSystemWindowManagerWhenAvailable {
                LuminareToggle("Restore window frame on drag", isOn: $restoreWindowFrameOnDrag)
                LuminareButton("Padding", "Configure…") {
                    isPaddingConfigurationViewPresented = true
                }
                .luminareModal(isPresented: $isPaddingConfigurationViewPresented) {
                    PaddingConfigurationView(isPresented: $isPaddingConfigurationViewPresented)
                        .frame(width: 400)
                }
                .luminareModalCornerRadius(24)
            }
        }
    }

    private var cursorSection: some View {
        LuminareSection(String(localized: "Cursor", comment: "Section header shown in settings")) {
            LuminareToggle("Move cursor with window", isOn: $moveCursorWithWindow)

            LuminareToggle("Resize window under cursor", isOn: $resizeWindowUnderCursor)

            // If the system WM is enabled, the window under the cursor requires focus.
            if resizeWindowUnderCursor, !useSystemWindowManagerWhenAvailable {
                LuminareToggle("Focus window on resize", isOn: $focusWindowOnResize)
            }
        }
    }

    private var windowSnappingSection: some View {
        LuminareSection(String(localized: "Window Snapping", comment: "Section header shown in settings")) {
            if #available(macOS 15, *) {
                LuminareToggle(isOn: $windowSnapping) {
                    if SystemWindowManager.MoveAndResize.snappingEnabled {
                        Text("Enable window snapping")
                            .padding(.trailing, 4)
                            .luminareToolTip(attachedTo: .topTrailing) {
                                Text("macOS's \"Tile by dragging windows to screen edges\" feature is currently\nenabled, which will conflict with Wally‘s Hand's window snapping functionality.")
                                    .padding(6)
                            }
                    } else {
                        Text("Enable window snapping")
                    }
                }
            } else {
                LuminareToggle("Enable window snapping", isOn: $windowSnapping)
            }

            if windowSnapping {
                LuminareToggle("Suppress Mission Control", isOn: $suppressMissionControlOnTopDrag)
            }
        }
    }

    private var stageManagerSection: some View {
        LuminareSection(String(localized: "Stage Manager", comment: "Section header shown in settings")) {
            LuminareToggle("Respect Stage Manager", isOn: $respectStageManager)

            if respectStageManager {
                LuminareSlider(
                    "Stage strip size",
                    value: $stageStripSize.doubleBinding,
                    in: 50...250,
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    suffix: Text("px", comment: "Unit symbol: pixels")
                )
            }
        }
    }
}
