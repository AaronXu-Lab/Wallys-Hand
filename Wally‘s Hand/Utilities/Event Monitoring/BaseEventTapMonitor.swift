//
//  BaseEventTapMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-07.
//

import CoreGraphics
import Foundation
import Scribe

/// Base class to share common functionality. DO NOT USE DIRECTLY!
@Loggable
class BaseEventTapMonitor: EventMonitorProtocol, Identifiable, Equatable {
    // Allow at most 5 restarts within any 2 second window before giving up
    private static let restartWindow: Duration = .seconds(2)
    private static let maxRestartsInWindow = 5

    /// The raw refcon points to this box, never to a monitor that may be deinitializing.
    final class CallbackContext {
        weak var monitor: BaseEventTapMonitor?
    }

    let callbackContext = CallbackContext()
    private let lifecycleLock = NSRecursiveLock()
    let id = UUID()

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var runLoopSource: CFRunLoopSource?
    private var readableIdentifier: String?
    private var isEnabled = false

    private var restartTimestamps: [ContinuousClock.Instant] = []

    init() {
        callbackContext.monitor = self
    }

    /// Serializes callbacks with stop so clients can safely reset their state afterwards.
    func handleEvent(
        type: CGEventType,
        event: CGEvent,
        callback: () -> Unmanaged<CGEvent>?
    ) -> Unmanaged<CGEvent>? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        guard isEnabled else { return Unmanaged.passUnretained(event) }

        // Disabled notifications are identified by the callback type, not the event payload.
        // PerformBlock requires the CFString rawValue, not a boxed CFRunLoopMode.
        if type == .tapDisabledByTimeout {
            guard let runLoop else { return Unmanaged.passUnretained(event) }
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in
                self?.attemptRestart()
            }
            CFRunLoopWakeUp(runLoop)
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput {
            return Unmanaged.passUnretained(event)
        }

        return callback()
    }

    deinit {
        tearDownEventTap()
    }

    func setupRunLoopSource(eventTap: CFMachPort, readableIdentifier: String) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        let runLoop = EventTapThread.shared.runLoop
        self.readableIdentifier = readableIdentifier

        if let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) {
            self.eventTap = eventTap
            self.runLoop = runLoop
            self.runLoopSource = runLoopSource
            CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
            CFRunLoopWakeUp(runLoop)
        } else {
            CFMachPortInvalidate(eventTap)
        }
    }

    func start() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard let eventTap else { return }

        guard CFMachPortIsValid(eventTap) else {
            let identifier = readableIdentifier ?? id.uuidString
            log.warn("Event tap '\(identifier)' mach port is invalid, tearing down")
            tearDownEventTap()
            return
        }

        isEnabled = true

        if let readableIdentifier {
            log.info("Starting BaseEventTapMonitor '\(readableIdentifier)'")
        } else {
            log.info("Starting BaseEventTapMonitor with ID \(id)")
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard eventTap != nil else { return }

        if let readableIdentifier {
            log.info("Stopping BaseEventTapMonitor '\(readableIdentifier)'")
        } else {
            log.info("Stopping BaseEventTapMonitor with ID \(id)")
        }

        tearDownEventTap()
    }

    static func == (lhs: BaseEventTapMonitor, rhs: BaseEventTapMonitor) -> Bool {
        lhs.id == rhs.id
    }

    /// Attempts to re-enable the tap after a timeout, giving up if it's restarting too frequently.
    private func attemptRestart() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard isEnabled else { return }
        let now = ContinuousClock.now
        let windowStart = now - Self.restartWindow
        restartTimestamps.removeAll { $0 < windowStart }
        restartTimestamps.append(now)

        let identifier = readableIdentifier ?? id.uuidString

        if restartTimestamps.count > Self.maxRestartsInWindow {
            log.warn("Event tap '\(identifier)' restart cascade detected, tearing down")
            tearDownEventTap()
            return
        }

        start()
    }

    private func tearDownEventTap() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard eventTap != nil || runLoopSource != nil else { return }

        let eventTap = eventTap
        let runLoop = runLoop
        let runLoopSource = runLoopSource

        self.eventTap = nil
        self.runLoop = nil
        self.runLoopSource = nil
        isEnabled = false

        if let eventTap, CFMachPortIsValid(eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        guard let runLoop, let runLoopSource else { return }

        // Keep the refcon and port alive until the tap thread drains pending callbacks.
        // Never capture self here: this path also runs from deinit.
        let context = callbackContext
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
            withExtendedLifetime((context, eventTap)) {}
        }
        CFRunLoopWakeUp(runLoop)
    }
}
