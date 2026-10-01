//
//  CustomActionConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-27.
//

import Defaults
import AaronUI
import SwiftUI

struct CustomActionConfigurationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var luminareAnimation: Animation { reduceMotion ? .linear(duration: 0) : AUIMotion.fast }

    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var action: WindowAction
    @State private var currentTab: Tab = .position
    @State private var isDeferringExternalCommit = false

    private enum Tab: LocalizedStringKey, CaseIterable {
        case position = "Position", size = "Size"

        var image: Image {
            switch self {
            case .position:
                Image(systemName: "viewfinder")
            case .size:
                Image(systemName: "rectangle.expand.diagonal")
            }
        }
    }

    private let anchors: [CustomWindowActionAnchor] = [
        .topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight
    ]

    private var actionUnit: CustomWindowActionUnit {
        action.unit ?? .percentage
    }

    private var showMacOSCenterToggle: Bool {
        action.anchor ?? .center == .center || action.anchor == .macOSCenter
    }

    private let screenSize: CGSize = NSScreen.main?.frame.size ?? NSScreen.screens[0].frame.size

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        _windowAction = action
        _isPresented = isPresented
        _action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        SettingsForm(scrolls: false) {
            configurationSections()
        }
        .onChange(of: action) { newValue in
            guard !isDeferringExternalCommit else { return }
            windowAction = newValue
        }
    }

    @ViewBuilder
    private func configurationSections() -> some View {
        SettingsSection {
            AUIInput(
                "Custom Action",
                text: Binding(
                    get: { action.name ?? "" },
                    set: { action.name = $0 }
                )
            )

        }

        SettingsSection {
            tabPicker()
            unitToggle()
        }

        SettingsSection {
            if currentTab == .position {
                positionConfiguration()
            } else {
                sizeConfiguration()
            }
        }
        .animation(luminareAnimation, value: action.unit)
        .onAppear {
            if action.unit == nil {
                action.unit = .percentage
            }

            if action.sizeMode == nil {
                action.sizeMode = .custom
            }

            if action.width == nil {
                action.width = 80
            }

            if action.height == nil {
                action.height = 80
            }

            if action.positionMode == nil {
                action.positionMode = .generic
            }

            if action.anchor == nil {
                action.anchor = .center
            }
        }
    }

    private func tabPicker() -> some View {
        SettingsChoiceGrid(
            elements: Tab.allCases,
            selection: $currentTab.animation(luminareAnimation),
            columns: 2
        ) { tab in
            HStack(spacing: 6) {
                tab.image
                Text(tab.rawValue)
            }
            .fixedSize()
        }

    }

    private func unitToggle() -> some View {
        SettingsToggle("Use pixels", isOn: Binding(get: { action.unit == .pixels }, set: { action.unit = $0 ? .pixels : .percentage }))
            .onChange(of: actionUnit) { unit in
                if unit == .percentage {
                    if let xPoint = action.xPoint { action.xPoint = max(0, min(100, xPoint)) }
                    if let yPoint = action.yPoint { action.yPoint = max(0, min(100, yPoint)) }
                    if let width = action.width { action.width = max(0, min(100, width)) }
                    if let height = action.height { action.height = max(0, min(100, height)) }
                }
            }
    }

    private func positionConfiguration() -> some View {
        Group {
            SettingsToggle(
                "Use coordinates",
                isOn: Binding(
                    get: {
                        action.positionMode == .coordinates
                    },
                    set: { newValue in
                        withAnimation(luminareAnimation) {
                            action.positionMode = newValue ? .coordinates : .generic
                        }
                    }
                )
            )

            if action.positionMode ?? .generic == .generic {
                SettingsChoiceGrid(
                    elements: anchors,
                    selection: Binding(
                        get: {
                            // since center/macOS center use the same icon on the picker
                            if action.anchor == .macOSCenter {
                                return .center
                            }

                            return action.anchor ?? .center
                        },
                        set: { newValue in
                            withAnimation(luminareAnimation) {
                                action.anchor = newValue
                            }
                        }
                    ),
                    columns: 3
                ) { anchor in
                    if let action = anchor.iconAction {
                        IconView(action: action)
                            .accessibilityLabel(Text(action.getName()))
                    }
                }

                if showMacOSCenterToggle {
                    SettingsToggle(
                        isOn: Binding(
                            get: {
                                action.anchor == .macOSCenter
                            },
                            set: {
                                action.anchor = $0 ? .macOSCenter : .center
                            }
                        )
                    ) {
                        if let infoText = action.direction.infoText {
                            Text("Use macOS center", comment: "Toggle to enable macOS-style centering in custom actions")
                                .padding(.trailing, 4)
                                .settingsHelp() {
                                    Text(infoText)
                                        .padding(6)
                                }
                        } else {
                            Text("Use macOS center", comment: "Toggle to enable macOS-style centering in custom actions")
                        }
                    }
                }
            } else {
                SettingsNumericField(
                    String(localized: "X", comment: "X axis label"),
                    value: Binding(
                        get: {
                            action.xPoint ?? 0
                        },
                        set: {
                            action.xPoint = actionUnit.roundIfNeeded($0)
                        }
                    ),
                    in: actionUnit == .percentage ? 0...100 : 0...Double(screenSize.width),
                    format: .number.precision(actionUnit.fractionLength),
                    clampsUpper: false,
                    suffix: Text(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    onEditingChanged: handleSliderEditingChanged,
                    onEditingCommit: commitSliderChanges
                )

                SettingsNumericField(
                    String(localized: "Y", comment: "Y axis label"),
                    value: Binding(
                        get: {
                            action.yPoint ?? 0
                        },
                        set: {
                            action.yPoint = actionUnit.roundIfNeeded($0)
                        }
                    ),
                    in: actionUnit == .percentage ? 0...100 : 0...Double(screenSize.height),
                    format: .number.precision(actionUnit.fractionLength),
                    clampsUpper: false,
                    suffix: Text(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    onEditingChanged: handleSliderEditingChanged,
                    onEditingCommit: commitSliderChanges
                )
            }
        }
    }

    private func sizeConfiguration() -> some View {
        Group {
            SettingsChoiceGrid(
                elements: CustomWindowActionSizeMode.allCases,
                selection: Binding(
                    get: {
                        action.sizeMode ?? .custom
                    },
                    set: { newValue in
                        withAnimation(luminareAnimation) {
                            action.sizeMode = newValue
                        }
                    }
                ),
                columns: 3
            ) { mode in
                VStack(spacing: 4) {
                    mode.image
                    Text(mode.name)
                }
                .compositingGroup()
            }


            if action.sizeMode ?? .custom == .custom {
                SettingsNumericField(
                    "Width",
                    value: Binding(
                        get: {
                            action.width ?? 100
                        },
                        set: {
                            action.width = actionUnit.roundIfNeeded($0)
                        }
                    ),
                    in: actionUnit == .percentage ? 0...100 : 0...Double(screenSize.width),
                    format: .number.precision(actionUnit.fractionLength),
                    clampsUpper: false,
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    onEditingChanged: handleSliderEditingChanged,
                    onEditingCommit: commitSliderChanges
                )

                SettingsNumericField(
                    "Height",
                    value: Binding(
                        get: {
                            action.height ?? 100
                        },
                        set: {
                            action.height = actionUnit.roundIfNeeded($0)
                        }
                    ),
                    in: actionUnit == .percentage ? 0...100 : 0...Double(screenSize.height),
                    format: .number.precision(actionUnit.fractionLength),
                    clampsUpper: false,
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    onEditingChanged: handleSliderEditingChanged,
                    onEditingCommit: commitSliderChanges
                )
            }
        }
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        isDeferringExternalCommit = isEditing
    }

    private func commitSliderChanges() {
        isDeferringExternalCommit = false
        windowAction = action
    }
}
