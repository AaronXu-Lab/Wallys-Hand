//
//  WorkspaceWindowManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Combine
import Defaults
import Luminare
import Scribe
import SwiftUI

@Loggable
@MainActor
final class WorkspaceWindowManager: ObservableObject {
    static let shared = WorkspaceWindowManager()
    private var controller: NSWindowController?
    // Persist stable IDs rather than localized labels. Settings never replace the last tool.
    @Published var destination: AppDestination {
        didSet {
            if destination.isTool { UserDefaults.standard.set(destination.rawValue, forKey: "workspace.lastTool") }
        }
    }
    @Published var windowTab: WindowToolTab {
        didSet { UserDefaults.standard.set(windowTab.rawValue, forKey: "workspace.windowTab") }
    }

    var window: NSWindow? {
        controller?.window
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "workspace.lastTool") ?? ""
        let tool = AppDestination(rawValue: saved)
        if let tool, tool.isTool { destination = tool }
        else { destination = .windows }
        windowTab = WindowToolTab(rawValue: UserDefaults.standard.string(forKey: "workspace.windowTab") ?? "") ?? .keybinds
    }

    /// Menu commands use explicit destinations; reopening the app retains the current page.
    func show(_ destination: AppDestination) {
        self.destination = destination
        show()
    }

    func show() {
        if controller == nil {
            let window = LuminareWindow {
                WorkspaceView(model: self)
                    .frame(height: 660)
            }

            SkyLightToolBelt.setBackgroundBlur(
                windowID: CGWindowID(window.windowNumber),
                radius: 20
            )

            window.title = Bundle.main.appName
            window.backgroundColor = .white.withAlphaComponent(0.001)
            window.ignoresMouseEvents = false

            controller = NSWindowController(window: window)
        }

        NSApp.setActivationPolicy(.regular)

        controller?.showWindow(self)
        window?.orderFrontRegardless()

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        log.success("Workspace window opened")
    }

    func close() {
        if let controller {
            controller.close()
            self.controller = nil

            log.success("Workspace window closed")
        }

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
