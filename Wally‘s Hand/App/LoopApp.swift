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
    @Environment(\.openWindow) private var openWindow

    init() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == "--cli" {
            exit(PortCLI.run(Array(arguments.dropFirst())))
        }
    }

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
                #if DEBUG
                    Divider()
                    Button("Temp · 端口管理布局") { openWindow(id: "temp-port-layout") }
                #endif
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { WorkspaceWindowManager.shared.show(.settings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
        #if DEBUG
            SwiftUI.Window("Temp · 端口管理布局", id: "temp-port-layout") {
                TempPortManagementView()
                    .frame(minWidth: TempPortLayout.previewWidth, minHeight: 500)
            }
            .defaultSize(width: TempPortLayout.previewWidth, height: TempPortLayout.previewHeight)
        #endif
    }
}
