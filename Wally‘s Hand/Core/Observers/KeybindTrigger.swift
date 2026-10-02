//
//  KeybindTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa
import Defaults
import Scribe

/// Monitors `keyDown`, `keyUp`, and `flagsChanged` events using an ActiveEventMonitor, invoking Wally‘s Hand’s open and close callbacks as needed.
/// Additionally, this class manages keybind action retrieval and updates Wally‘s Hand based on those actions.
@Loggable
final class KeybindTrigger {
    // Parameters
    private let windowActionCache: WindowActionCache
    private let openCallback: (WindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    // State-tracking
    private let stateLock = NSLock()
    private var pressedKeys: Set<CGKeyCode> = []
    private var eventFlags: CGEventFlags = []
    private var eventMonitor: ActiveEventMonitor?

    private var systemKeybindCache: Set<Set<CGKeyCode>> = []
    private var keybindCacheUpdatedAt: ContinuousClock.Instant?
    private let keybindCacheLifetime: ContinuousClock.Duration = .seconds(30)

    /// Special events only contain the globe key, as it can also be used as an emoji key.
    private let specialEventKeys: [CGKeyCode] = [.kVK_Globe_Emoji]

    private var triggerKey: Set<CGKeyCode> { Defaults[.triggerKey] }

    /// Initializes a ``KeybindObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the trigger key is pressed, and Wally‘s Hand should be activated.
    ///   - closeCallback: what to do when the trigger key is released, and Wally‘s Hand should be closed.
    init(
        windowActionCache: WindowActionCache,
        openCallback: @escaping (WindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    @MainActor
    func start() async {
        guard AccessibilityManager.shared.isGranted else {
            return
        }

        guard !Task.isCancelled else { return }
        stop()

        let eventMonitor = ActiveEventMonitor(
            "keybind_trigger",
            events: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event -> ActiveEventMonitor.EventHandling in
            guard let self else { return .forward }
            stateLock.lock()
            defer { stateLock.unlock() }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                .baseKey(flags: .init(rawValue: UInt(event.flags.rawValue)))

            var filteredFlags = event.flags
            if keyCode.isFnSpecialKey, !eventFlags.contains(.maskSecondaryFn) {
                filteredFlags.remove(.maskSecondaryFn)
            }

            let isLoopOpen = checkIfLoopOpen()
            eventFlags = filteredFlags

            if event.type == .keyUp {
                pressedKeys.remove(keyCode)
            } else if event.type == .keyDown {
                pressedKeys.insert(keyCode)
            }

            // Special events such as the emoji key
            if specialEventKeys.contains(keyCode) {
                return .forward
            }

            // If this is a valid event, don't passthrough
            let result = performKeybind(
                type: event.type,
                isARepeat: event.getIntegerValueField(.keyboardEventAutorepeat) == 1,
                flags: filteredFlags,
                isLoopOpen: isLoopOpen
            )

            if result == .consume {
                log.debug("Blocked event")
                return .ignore
            }

            // If this shouldn't consume the event, and Wally‘s Hand isn't opening,
            // check if it was a system keybind (ex. screenshot), and in that case, passthrough and force-close Wally‘s Hand
            refreshSystemKeybindCacheIfNeeded()
            if result != .opening, event.type == .keyDown, systemKeybindCache.contains(pressedKeys) {
                closeLoop(forceClose: true)
            }

            return .forward
        }

        eventMonitor.start()
        self.eventMonitor = eventMonitor
    }

    @MainActor
    func stop() {
        eventMonitor?.stop()
        eventMonitor = nil

        // stop() drains any in-flight callback before taking the key state lock.
        stateLock.withLock {
            pressedKeys = []
            eventFlags = []
            systemKeybindCache = []
            keybindCacheUpdatedAt = nil
        }
    }

    enum PerformKeybindResult {
        case consume
        case forward
        case opening
    }

    /// Determines if an event corresponds to a valid Wally‘s Hand action.
    /// - Parameters:
    ///   - type: the type of this event.
    ///   - isARepeat: whether this event is a repeat event.
    ///   - flags: modifier flags associated with this event.
    ///   - isLoopOpen: whether Wally‘s Hand is currently open.
    /// - Returns: whether this event was processed by Wally‘s Hand.
    private func performKeybind(type: CGEventType, isARepeat: Bool, flags: CGEventFlags, isLoopOpen: Bool) -> PerformKeybindResult {
        let actions = windowActionCache.snapshot
        let flagKeys = flags.keyCodes
        let allPressedKeys: Set<CGKeyCode> = pressedKeys.union(flagKeys)

        let containsTrigger = allPressedKeys.isSuperset(of: triggerKey)
        let actionKeys: Set<CGKeyCode> = Set(allPressedKeys.subtracting(triggerKey).map(\.baseModifier))
        let allPressedKeysBaseModifiers: Set<CGKeyCode> = Set(allPressedKeys.map(\.baseModifier))

        if isLoopOpen {
            if pressedKeys.contains(.kVK_Escape) {
                closeLoop(forceClose: true)
                return .consume
            }

            if type == .keyUp {
                return .forward
            }

            if type != .keyDown, !containsTrigger {
                closeLoop(forceClose: false)
                return .forward
            }
        }

        if type != .keyUp { // keyDown for flagsChanged
            if containsTrigger {
                // Try an match directly with the action keys first, then fallback to just the key code.
                // This prevents failures when the user is tapping the keys in rapid succession.
                if let action = actions.actionsByKeybind[actionKeys] {
                    if !isARepeat || action.canRepeat {
                        openCallback(action)
                    }

                    // Only consume the event if the last command actually opened Wally‘s Hand.
                    return checkIfLoopOpen() ? .consume : .opening
                }

                // Only trigger Wally‘s Hand without an action if the only pressed keys perfectly matches the trigger key.
                if allPressedKeys == triggerKey {
                    openCallback(.init(.noSelection))
                    return .opening
                }
            } else if let bypassedAction = actions.bypassedActionsByKeybind[allPressedKeysBaseModifiers] {
                if !isARepeat || bypassedAction.canRepeat {
                    openCallback(bypassedAction)
                }

                return checkIfLoopOpen() ? .consume : .opening
            } else {
                closeLoop(forceClose: false)
            }
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return .forward
    }

    private func closeLoop(forceClose: Bool) {
        closeCallback(forceClose)
        pressedKeys = []
    }

    private func refreshSystemKeybindCacheIfNeeded() {
        let shouldRefresh: Bool = if let keybindCacheUpdatedAt {
            keybindCacheUpdatedAt.duration(to: .now) > keybindCacheLifetime
        } else {
            true
        }

        guard shouldRefresh else {
            return
        }

        systemKeybindCache = CGKeyCode.systemKeybinds
        keybindCacheUpdatedAt = .now
    }
}
