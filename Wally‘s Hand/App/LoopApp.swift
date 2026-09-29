//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsContentView(model: SettingsWindowManager.shared)
                .frame(height: 660)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { SettingsWindowManager.shared.show() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
