//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI

@main
enum WallyEntry {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == "--cli" {
            exit(PortCLI.run(Array(arguments.dropFirst())))
        }
        LoopApp.main()
    }
}

struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            WorkspaceView(model: WorkspaceWindowManager.shared)
                .frame(height: 990)
        }
        .commands {
            CommandMenu("工具") {
                Button("窗口管理") { WorkspaceWindowManager.shared.show(.windows) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("端口管理") { WorkspaceWindowManager.shared.show(.ports) }
                    .keyboardShortcut("2", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { WorkspaceWindowManager.shared.show(.settings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
