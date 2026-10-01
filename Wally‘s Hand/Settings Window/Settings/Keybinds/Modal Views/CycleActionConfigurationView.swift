//
//  CycleActionConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-03.
//

import Defaults
import AaronUI
import SwiftUI

struct CycleActionConfigurationView: View {
    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var action: WindowAction // this is so that onChange is called for each property

    @State private var selectedKeybinds = Set<WindowAction>()

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        self._windowAction = action
        self._isPresented = isPresented
        self._action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        SettingsForm(scrolls: false) {
            SettingsSection {
                AUIInput("Cycle Keybind", text: Binding(get: { action.name ?? "" }, set: { action.name = $0 }))

            }

            SettingsSection {
                SettingsActions {
                    Button("Add") {
                        if action.cycle == nil {
                            action.cycle = []
                        }

                        action.cycle?.insert(.init(.noAction), at: 0)
                    }

                    Button("Remove", role: .destructive) {
                        action.cycle?.removeAll(where: { selectedKeybinds.contains($0) })
                    }
                    .disabled(selectedKeybinds.isEmpty)
                }

                SettingsSelectionList(
                    items: Binding(
                        get: {
                            action.cycle ?? []
                        },
                        set: { newValue in
                            action.cycle = newValue
                        }
                    ),
                    selection: $selectedKeybinds,
                    id: \.id
                ) { item in
                    KeybindItemView(
                        item,
                        cycleIndex: action.cycle?.firstIndex(of: item.wrappedValue)
                    )
                    .environmentObject(KeybindsConfigurationModel())
                } emptyView: {
                    AUIEmptyState(String(localized: "Nothing to cycle through"), systemImage: "repeat",
                                  description: String(localized: "Press \"Add\" to add a cycle item"), type: .inline)
                }

            }
            .onChange(of: action) { windowAction = $0 }


        }
        .onAppear {
            if action.cycle == nil {
                action.cycle = []
            }
        }
    }
}
