import AppKit
import Defaults
import os

@main
struct EventMonitoringRegression {
    @MainActor
    static func main() async throws {
        setbuf(stdout, nil)
        alarm(30)
        defer { Defaults.Keys.testSuite.removePersistentDomain(forName: Defaults.Keys.testSuiteName) }
        try await cacheSnapshots()
        try await monitorLifecycle()
        print("PASS: event-monitoring regressions")
    }

    @MainActor
    private static func cacheSnapshots() async throws {
        let normal = WindowAction(.cycle, keybind: [1])
        let bypass = WindowAction(.right, keybind: [2], bypassTriggerKey: true)
        Defaults[.keybinds] = [normal, bypass]
        let cache = WindowActionCache()
        let initial = cache.snapshot
        precondition(initial.actionsByKeybind[[1]] == normal)
        precondition(initial.actionsByKeybind[[1, .kVK_Shift]] == nil)
        precondition(initial.bypassedActionsByKeybind[[2]] == bypass)

        try await Task.sleep(for: .milliseconds(50))
        await Task.detached {
            DispatchQueue.concurrentPerform(iterations: 4) { worker in
                for iteration in 0..<1_000 {
                    if worker == 0 {
                        Defaults[.keybinds] = (0..<16).map { index in
                            WindowAction(
                                iteration.isMultiple(of: 2) ? .cycle : .left,
                                keybind: [CGKeyCode(index)],
                                bypassTriggerKey: index.isMultiple(of: 2)
                            )
                        }
                    } else {
                        let snapshot = cache.snapshot
                        for action in snapshot.actionsByKeybind.values {
                            precondition(snapshot.actionsByIdentifier[action.id] == action)
                        }
                        for action in snapshot.bypassedActionsByKeybind.values {
                            precondition(snapshot.actionsByIdentifier[action.id] == action)
                        }
                    }
                }
            }
        }.value
        let final = WindowAction(.right, keybind: [42])
        Defaults[.keybinds] = [final]
        for _ in 0..<500 {
            if cache.snapshot.actionsByIdentifier[final.id] != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(cache.snapshot.actionsByKeybind[[42]] == final, "Settings updates must reach readers")
        precondition(initial.actionsByKeybind[[1]] == normal, "Old snapshots must stay immutable")
        print("PASS: coherent cache snapshots during concurrent settings updates")
    }

    private static func drainTapThread() async {
        await withCheckedContinuation { continuation in
            let runLoop = EventTapThread.shared.runLoop
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
                continuation.resume()
            }
            CFRunLoopWakeUp(runLoop)
        }
    }

    private static func monitorLifecycle() async throws {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        var monitor: BaseEventTapMonitor? = BaseEventTapMonitor()
        let context = monitor!.callbackContext
        _ = monitor!.handleEvent(type: .keyDown, event: event) {
            preconditionFailure("Stopped monitor dispatched an event")
        }
        monitor = nil
        precondition(context.monitor == nil, "Callback context must not retain the monitor")

        // No permission prompt and no synthetic system input. These tests require existing access.
        guard CGPreflightListenEventAccess() else {
            print("SKIP: live tap teardown tests (Input Monitoring access unavailable)")
            return
        }
        for _ in 0..<50 {
            var tap: PassiveEventMonitor? = PassiveEventMonitor("regression", events: [.keyDown]) { _ in }
            tap!.start()
            let calls = OSAllocatedUnfairLock(initialState: 0)
            _ = tap!.handleEvent(type: .keyDown, event: event) {
                calls.withLock { $0 += 1 }
                return Unmanaged.passUnretained(event)
            }
            precondition(calls.withLock { $0 == 1 }, "Tap creation failed despite preflight access")
            // Notification type deliberately differs from event.type.
            _ = tap!.handleEvent(type: .tapDisabledByTimeout, event: event) {
                preconditionFailure("Timeout notification reached the keyboard handler")
            }
            tap!.stop()
            await drainTapThread()
            _ = tap!.handleEvent(type: .keyDown, event: event) {
                preconditionFailure("Queued restart revived a stopped tap")
            }
            tap = nil
        }
        for _ in 0..<100 {
            // Exercise deinit without an explicit stop, including its deferred refcon cleanup.
            var tap: PassiveEventMonitor? = PassiveEventMonitor("deinit", events: [.keyDown]) { _ in }
            tap!.start()
            weak var releasedTap = tap
            tap = nil
            // A callback already in flight may briefly retain the monitor.
            await drainTapThread()
            precondition(releasedTap == nil)
        }
        await drainTapThread()
        print("PASS: timeout classification, stopped tap restart suppression and deinit cleanup")
    }
}
