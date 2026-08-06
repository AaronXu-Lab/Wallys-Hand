//
//  SettingsWindowManager.swift
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
final class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()
    private var controller: NSWindowController?
    @Published var currentTab: SettingsTab = .behavior

    var window: NSWindow? {
        controller?.window
    }

    private init() {}

    func show() {
        if controller == nil {
            let window = LuminareWindow {
                SettingsContentView(model: self)
                    .frame(height: 620)
            }

            SkyLightToolBelt.setBackgroundBlur(
                windowID: CGWindowID(window.windowNumber),
                radius: 20
            )

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

        log.success("Settings window opened")
    }

    func close() {
        if let controller {
            controller.close()
            self.controller = nil

            log.success("Settings window closed")
        }

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
