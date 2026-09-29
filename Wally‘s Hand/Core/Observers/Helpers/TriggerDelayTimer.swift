//
//  TriggerDelayTimer.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-27.
//

import Defaults
import Foundation

/// A utility class that delays triggering an action until a specified amount of time has passed.
///
/// It is used to defer the execution of a callback (in this case, opening Wally‘s Hand) by a user-configurable
/// number of seconds, as defined by the user’s `Defaults[.triggerDelay]` setting.
/// When using keybinds, you may also want to update the starting action without restarting the timer.
/// In that case, use the `updateStartingAction` method.
final class TriggerDelayTimer {
    // The event tap updates/cancels this timer while its task completes on MainActor.
    private let stateLock = NSRecursiveLock()
    private var generation: UInt64 = 0
    private var triggerDelayTimer: Task<(), Never>?
    private var startingAction: WindowAction = .init(.noSelection)
    private let openCallback: (WindowAction) -> ()
    private var triggerDelay: CGFloat { Defaults[.triggerDelay] }

    /// Indicates whether the delay timer is currently active.
    var isActive: Bool { stateLock.withLock { triggerDelayTimer != nil } }

    /// Creates a new `TriggerDelayTimer` instance with the specified callback to invoke after a user-configured delay has elapsed.
    /// - Parameter openCallback: A closure that is called once the trigger delay completes successfully. The closure receives the latest `WindowAction` depending on what has been set.
    init(openCallback: @escaping (WindowAction) -> ()) {
        self.openCallback = openCallback
    }

    deinit {
        cancel()
    }

    /// Handles a trigger event (such as a key press) and starts or restarts the delay timer.
    ///
    /// If another trigger is received before the delay elapses, the previous timer is canceled and restarted.
    /// Once the configured delay duration passes without interruption, the provided callback is invoked, with the latest inputted starting action.
    /// - Parameter startingAction: The `WindowAction` associated with the trigger.
    func handleTrigger(startingAction action: WindowAction) {
        stateLock.withLock {
            cancel()
            startingAction = action
            let scheduledGeneration = generation
            let delay = triggerDelay

            triggerDelayTimer = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                self?.fire(generation: scheduledGeneration)
            }
        }
    }

    private func fire(generation scheduledGeneration: UInt64) {
        stateLock.withLock {
            // A canceled task may already have woken up. Never let it fire or clear a newer timer.
            guard generation == scheduledGeneration, triggerDelayTimer != nil else { return }
            let action = startingAction
            cancel()
            openCallback(action)
        }
    }

    /// Updates the stored `startingAction` value without restarting the timer. To be used with keybinds.
    /// - Parameter newAction: The new `WindowAction` to associate with the current trigger delay.
    func updateStartingAction(with newAction: WindowAction) {
        stateLock.withLock { startingAction = newAction }
    }

    /// Cancels any active delay timer and clears the stored action.
    func cancel() {
        stateLock.withLock {
            generation &+= 1
            triggerDelayTimer?.cancel()
            triggerDelayTimer = nil
            startingAction = .init(.noSelection)
        }
    }
}
