//
//  AppDelegate.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-05.
//

import Darwin
import Defaults
import Scribe
import SwiftUI

@Loggable
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let terminateNotificationName = Notification.Name("com.xuweinan.LoopJust.terminate")
    private var terminateObserver: Any?
    private var terminating = false
    private var cliServer: PortCLIServer?
    private var menuBarController: MenuBarController?
    private var windowManagementTask: Task<Void, Never>?

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return
            event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_: Notification) {
        configureLogging()
        cliServer = PortCLIServer()
        #if DEBUG
        // UI review without event taps, permission prompts, or service supervision.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--preview-workspace") || arguments.contains("--preview-settings") {
            if arguments.contains("--preview-settings") { WorkspaceWindowManager.shared.show(.ports) }
            else { WorkspaceWindowManager.shared.show() }
            return
        }
        #endif
        menuBarController = MenuBarController()

        // Register before broadcasting so other instances can receive the signal
        registerTerminateObserver()

        Task {
            await Defaults.iCloud.waitForSyncCompletion()
        }

        // Show settings window only if not launched as login item AND startHidden is disabled
        if !launchedAsLoginItem, !Defaults[.startHidden], !ProcessInfo.processInfo.arguments.contains("--cli-background") {
            WorkspaceWindowManager.shared.show()
        } else {
            // Closing also hides the dock icon if needed.
            WorkspaceWindowManager.shared.close()
        }

        LaunchAtLoginManager.shared.start()

        let stalePIDs = broadcastTerminateToOtherInstances()

        // Wait for other instances to fully exit before installing event taps to prevent conflicts
        Task { @MainActor in
            await waitForInstancesToExit(pids: stalePIDs, timeout: .seconds(15))
            windowManagementTask = Task { @MainActor in
                for await enabled in Defaults.updates(.windowManagementEnabled, initial: true) {
                    guard !Task.isCancelled else { break }
                    if enabled {
                        LoopManager.shared.start()
                        WindowDragManager.shared.addObservers()
                    } else {
                        LoopManager.shared.shutdown()
                        WindowDragManager.shared.shutdown()
                    }
                }
            }
        }
    }

    /// Subscribes to the terminate notification so this instance shuts down when a newer Wally‘s Hand instance launches.
    private func registerTerminateObserver() {
        terminateObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.terminateNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }

            // Ignore our own broadcast (for obvious reasons)
            if let senderPID = notification.userInfo?["pid"] as? Int,
               senderPID == Int(ProcessInfo.processInfo.processIdentifier) {
                return
            }

            log.info("Received terminate broadcast from newer Wally‘s Hand instance, shutting down")
            NSApp.terminate(nil)
        }
    }

    /// Sends the terminate notification to any other running Wally‘s Hand instances, and returns their PIDs.
    @discardableResult
    private func broadcastTerminateToOtherInstances() -> [pid_t] {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let bundleId = Bundle.main.bundleIdentifier ?? "com.xuweinan.LoopJust"

        let otherInstances = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleId && $0.processIdentifier != currentPID
        }

        guard !otherInstances.isEmpty else {
            log.info("No other Wally‘s Hand instances found")
            return []
        }

        log.info("Found \(otherInstances.count) other Wally‘s Hand instance(s), broadcasting terminate notification")

        DistributedNotificationCenter.default().post(
            name: Self.terminateNotificationName,
            object: nil,
            userInfo: ["pid": Int(currentPID)]
        )

        return otherInstances.map(\.processIdentifier)
    }

    /// Waits until all provided PIDs have exited, or until the timeout is reached.
    private func waitForInstancesToExit(pids: [pid_t], timeout: Duration) async {
        guard !pids.isEmpty else { return }

        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            let allGone = pids.allSatisfy { NSRunningApplication(processIdentifier: $0) == nil }
            if allGone {
                log.info("All prior Wally‘s Hand instances have exited")
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        let surviving = pids.filter { NSRunningApplication(processIdentifier: $0) != nil }
        if !surviving.isEmpty {
            log.warn("Timed out waiting for prior Wally‘s Hand instances to exit, force killing \(surviving.count) instance(s)")
            for pid in surviving {
                kill(pid, SIGKILL)
            }
        }
    }

    /// Applies baseline logging configuration for Scribe.
    private func configureLogging() {
        LogManager.shared.configuration.includeFileAndLineNumber = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        WorkspaceWindowManager.shared.close()
        return false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        WorkspaceWindowManager.shared.show()
        return true
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        windowManagementTask?.cancel()
        // LoopManager and WindowDragManager are explicitly shut down so that their
        // event monitors are stopped immediately (in case they are active)
        LoopManager.shared.shutdown()
        WindowDragManager.shared.shutdown()
        guard !terminating else { return .terminateLater }
        terminating = true
        PortServiceManager.shared.shutdown {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
