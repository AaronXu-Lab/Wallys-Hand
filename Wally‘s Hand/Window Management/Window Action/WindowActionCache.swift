//
//  WindowActionCache.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-11.
//

import AppKit
import Defaults
import os
import Scribe

/// Caches the user's actions in a dictionary keyed by its keybind.
/// This is called from `KeybindObserver`, to retrieve the user's actions in an efficient manner.
@Loggable
final class WindowActionCache {
    struct Snapshot {
        var actionsByKeybind: [Set<CGKeyCode>: WindowAction] = [:]
        var bypassedActionsByKeybind: [Set<CGKeyCode>: WindowAction] = [:]
        var actionsByIdentifier: [UUID: WindowAction] = [:]
    }

    private let cache = OSAllocatedUnfairLock(initialState: Snapshot())

    /// Readers retain one immutable generation while settings build the next one.
    var snapshot: Snapshot { cache.withLock { $0 } }

    private var observationTask: Task<(), Never>?

    /// Initializes a new instance of `WindowActionCache`.
    /// Will automatically build cache, and update according to changes the user makes to Wally‘s Hand's keybinds.
    init() {
        regenerateCache()
        self.observationTask = Task { [weak self] in
            let updates = Defaults.updates(
                .keybinds,
                .cycleBackwardsOnShiftPressed
            )

            for await _ in updates {
                guard
                    !Task.isCancelled,
                    let self
                else {
                    break
                }

                regenerateCache()
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    /// Rebuilds the cache and includes extra entries for cycle actions with shift keys if the user has enabled `cycleBackwardsOnShiftPressed`.
    private func regenerateCache() {
        let keybinds: [WindowAction] = Defaults[.keybinds].filter { !$0.keybind.isEmpty }

        var snapshot = Snapshot()
        let cycleBackwardsOnShiftPressed: Bool = Defaults[.cycleBackwardsOnShiftPressed]

        let normalActions = keybinds.filter { $0.bypassTriggerKey != true }
        let bypassedActions = keybinds.filter { $0.bypassTriggerKey == true }

        // Normal actions: keybind is action-key only (without trigger key)
        snapshot.actionsByKeybind = Dictionary(
            normalActions.map { ($0.keybind, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        if cycleBackwardsOnShiftPressed {
            snapshot.actionsByKeybind.merge(
                normalActions
                    .filter { $0.direction == .cycle }
                    .map { ($0.keybind.union([.kVK_Shift]), $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }

        snapshot.bypassedActionsByKeybind = Dictionary(
            bypassedActions.map { ($0.keybind, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        snapshot.actionsByIdentifier = Dictionary(
            keybinds.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        cache.withLock { [snapshot] in $0 = snapshot }
        log.info("Regenerated cache; normal: \(snapshot.actionsByKeybind.count), bypassed: \(snapshot.bypassedActionsByKeybind.count)")
    }
}
