//
//  PaddingConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import AaronUI
import SwiftUI

struct PaddingConfigurationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var luminareAnimation: Animation { reduceMotion ? .linear(duration: 0) : AUIMotion.fast }
    @Default(.enablePadding) private var enablePadding

    @State var paddingModel = Defaults[.padding]
    @State private var isDeferringDefaultsCommit = false
    @Binding var isPresented: Bool

    let range: ClosedRange<Double> = 0...100

    var body: some View {
        SettingsForm(scrolls: false) {
            SettingsSection {
                SettingsToggle("Apply padding", isOn: $enablePadding)
            }

            Group {
                SettingsSection {
                    paddingMode()

                    if !paddingModel.configureScreenPadding {
                        nonScreenPaddingConfiguration()
                    } else {
                        screenSidesPaddingConfiguration()
                    }
                }

                if paddingModel.configureScreenPadding {
                    SettingsSection {
                        screenInsetsPaddingConfiguration()
                    }
                }
            }
            .disabled(!enablePadding)


        }
        .onChange(of: paddingModel) { _ in
            guard !isDeferringDefaultsCommit else { return }
            // This fixes some weird animations.
            Defaults[.padding] = paddingModel
        }
    }

    func paddingMode() -> some View {
        SettingsChoiceGrid(
            elements: [false, true],
            selection: Binding(
                get: {
                    paddingModel.configureScreenPadding
                },
                set: { newValue in
                    withAnimation(luminareAnimation) {
                        paddingModel.configureScreenPadding = newValue

                        if !paddingModel.configureScreenPadding {
                            if paddingModel.allEqual {
                                let window = paddingModel.window
                                paddingModel.top = window
                                paddingModel.bottom = window
                                paddingModel.right = window
                                paddingModel.left = window
                            } else {
                                paddingModel.window = 0
                                paddingModel.top = 0
                                paddingModel.bottom = 0
                                paddingModel.right = 0
                                paddingModel.left = 0
                            }
                        }
                    }
                }
            ),
            columns: 2
        ) { custom in
            HStack(spacing: 6) {
                if custom {
                    Image(systemName: "slider.horizontal.3")
                    Text("Custom")
                } else {
                    Image(systemName: "square")
                    Text("Simple")
                }
            }
            .fixedSize()
        }
    }

    func nonScreenPaddingConfiguration() -> some View {
        SettingsNumericField(
            "Padding",
            value: Binding(
                get: {
                    paddingModel.window
                },
                set: {
                    paddingModel.window = $0
                    paddingModel.top = $0
                    paddingModel.bottom = $0
                    paddingModel.right = $0
                    paddingModel.left = $0
                }
            ),
            in: range,
            format: .number.precision(.fractionLength(0...1)),
            clampsUpper: false,
            suffix: Text("px", comment: "Unit symbol: pixels"),
            onEditingChanged: handleSliderEditingChanged,
            onEditingCommit: commitSliderChanges
        )
    }

    func screenSidesPaddingConfiguration() -> some View {
        Group {
            SettingsNumericField(
                String(localized: "Top", comment: "Label for a slider in Wally‘s Hand’s padding settings"),
                value: $paddingModel.top.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...1)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels"),
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )

            SettingsNumericField(
                String(localized: "Bottom", comment: "Label for a slider in Wally‘s Hand’s padding settings"),
                value: $paddingModel.bottom.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...1)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels"),
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )

            SettingsNumericField(
                String(localized: "Right", comment: "Label for a slider in Wally‘s Hand’s padding settings"),
                value: $paddingModel.right.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...1)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels"),
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )

            SettingsNumericField(
                String(localized: "Left", comment: "Label for a slider in Wally‘s Hand’s padding settings"),
                value: $paddingModel.left.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...1)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels"),
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )
        }
    }

    func screenInsetsPaddingConfiguration() -> some View {
        Group {
            SettingsNumericField(
                String(localized: "Window gaps", comment: "Label for a slider in Wally‘s Hand’s padding settings"),
                value: $paddingModel.window.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...1)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels"),
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )

            SettingsNumericField(
                value: $paddingModel.externalBar.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...1)),
                suffix: Text("px", comment: "Unit symbol: pixels"),
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            ) {
                Text("External bar", comment: "Label for a slider in Wally‘s Hand’s padding settings")
                    .padding(.trailing, 4)
                    .settingsHelp() {
                        Text("Use this if you are using a custom menubar.")
                            .padding(6)
                    }
            }
        }
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        isDeferringDefaultsCommit = isEditing
    }

    private func commitSliderChanges() {
        isDeferringDefaultsCommit = false
        Defaults[.padding] = paddingModel
    }
}
