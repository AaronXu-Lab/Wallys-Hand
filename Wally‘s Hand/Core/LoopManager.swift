//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import Defaults
import os
import Scribe
import SwiftUI

@Loggable
@MainActor
final class LoopManager {
    static let shared = LoopManager()
    private init() {}

    /// Context for the current resize operation, tracking frame and edge adjustment state.
    /// Initialized when Wally‘s Hand opens with a target window and screen.
    private(set) var resizeContext: ResizeContext = .init()

    private let windowActionCache = WindowActionCache()
    private var accessibilityCheckerTask: Task<(), Never>?

    /// Opening prepares resizeContext asynchronously. We track that setup separately
    /// so rapid trigger events cannot act on the previous/default context.
    private var isLoopOpening: Bool = false
    private var pendingOpeningAction: WindowAction?
    private var shouldCancelOpening: Bool = false

    private(set) var isLoopActive: Bool = false {
        didSet {
            let value = isLoopActive
            isLoopActiveMirror.withLock { $0 = value }
        }
    }

    private let isLoopActiveMirror = OSAllocatedUnfairLock<Bool>(initialState: false)
    nonisolated var isLoopActiveAtomic: Bool {
        isLoopActiveMirror.withLock { $0 }
    }

    private lazy var triggerKeyTimeoutTimer = TriggerKeyTimeoutTimer(
        closeCallback: { [weak self] forceClose in
            Task { await self?.closeLoop(forceClose: forceClose) }
        }
    )

    private(set) lazy var keybindTrigger = KeybindTrigger(
        windowActionCache: windowActionCache,
        openCallback: { [weak self] action in
            Task {
                await self?.openLoop(startingAction: action)
            }
        },
        closeCallback: { [weak self] forceClose in
            Task {
                await self?.closeLoop(forceClose: forceClose)
            }
        },
        checkIfLoopOpen: { [weak self] in
            self?.isLoopActiveAtomic ?? false
        }
    )

    func start() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else {
                    return
                }

                if status {
                    await keybindTrigger.start()
                } else {
                    keybindTrigger.stop()
                }
            }
        }
    }

    func shutdown() {
        accessibilityCheckerTask?.cancel()
        accessibilityCheckerTask = nil

        keybindTrigger.stop()
        triggerKeyTimeoutTimer.cancel()

        isLoopOpening = false
        pendingOpeningAction = nil
        shouldCancelOpening = false
        isLoopActive = false
    }
}

// MARK: - Opening/Closing Wally‘s Hand

extension LoopManager {
    private func openLoop(startingAction: WindowAction) async {
        guard AccessibilityManager.shared.isGranted else {
            return
        }

        guard !isLoopOpening else {
            if startingAction.direction != .noSelection {
                pendingOpeningAction = startingAction
            }
            return
        }

        guard !isLoopActive else {
            // If using Karabiner-Elements, TriggerKeybindObserver may call openLoop twice, as key events arrive in quick succession.
            // This happens because Karabiner-Elements sends modifier keys and other keys as separate, rapid events.
            // As a result, Wally‘s Hand might be opened before the full keybind is pressed.
            // In these cases, we can simply update the action instead of reopening Wally‘s Hand.
            if startingAction.direction != .noSelection { // Can switch to .noAction still!
                await changeAction(startingAction, disableHapticFeedback: true)
            }

            return
        }

        let window = WindowUtility.userDefinedTargetWindow()

        guard
            window?.isAppExcluded != true,
            (window?.fullscreen ?? false && Defaults[.ignoreFullscreen]) == false
        else {
            return
        }

        isLoopOpening = true
        pendingOpeningAction = nil
        shouldCancelOpening = false

        defer {
            isLoopOpening = false
            pendingOpeningAction = nil
            shouldCancelOpening = false
        }

        log.info("Opening Wally‘s Hand with starting action: \(startingAction.description) and target window: \(window?.description ?? "(none)")")

        let initialFrame = window?.frame ?? .zero

        resizeContext = ResizeContext(
            window: window,
            initialFrame: initialFrame
        )
        await resizeContext.refreshResolvedState()

        guard !shouldCancelOpening else {
            return
        }

        isLoopActive = true

        await changeAction(pendingOpeningAction ?? startingAction, disableHapticFeedback: true)

        triggerKeyTimeoutTimer.start()
    }

    private func closeLoop(forceClose: Bool) async {
        if isLoopOpening {
            shouldCancelOpening = true
        }

        guard isLoopActive == true else { return }
        log.info("Closing Wally‘s Hand (force closed: \(forceClose))")

        isLoopActive = false

        triggerKeyTimeoutTimer.cancel()

        // Handle normal actions with a target window
        if !forceClose {
            Defaults[.timesLooped] += 1
        }

    }
}

// MARK: - Changing Actions

extension LoopManager {
    /// Changes the action to the provided one, or the next cycle action if available.
    /// - Parameters:
    ///   - newAction: The action to change to. If a cycle is provided, Wally‘s Hand will use the current action as context to choose an appropriate next action.
    ///   - triggeredFromScreenChange: If this action was triggered from a screen change, this will prevent cycle keybinds from infinitely changing screens.
    ///   - disableHapticFeedback: This will prevent haptic feedback.
    private func changeAction(
        _ newAction: WindowAction,
        triggeredFromScreenChange: Bool = false,
        disableHapticFeedback: Bool = false
    ) async {
        guard
            isLoopActive,
            let currentScreen = resizeContext.screen ?? resolveAndStoreTargetScreen(
                action: newAction,
                window: resizeContext.window
            )
        else {
            return
        }

        guard resizeContext.action.id != newAction.id || newAction.canRepeat else {
            return
        }

        var newAction: WindowAction = newAction
        var newParentAction: WindowAction? = nil

        triggerKeyTimeoutTimer.cancel()
        triggerKeyTimeoutTimer.start()

        if newAction.direction == .cycle {
            newParentAction = newAction

            newAction = await getNextCycleAction(newAction)

            // Prevents an endless loop of cycling screens. example: when a cycle only consists of:
            // 1. next screen
            // 2. previous screen
            if triggeredFromScreenChange, newAction.direction.willChangeScreen {
                performHapticFeedback()
                return
            }
        } else {
            // Clear the parent cycle action when a direct shortcut is used.
            newParentAction = nil
        }

        if newAction.direction.willChangeScreen {
            var newScreen: NSScreen = currentScreen

            if newAction.direction == .nextScreen,
               let nextScreen = ScreenUtility.nextScreen(from: currentScreen) {
                newScreen = nextScreen
            }

            if newAction.direction == .previousScreen,
               let previousScreen = ScreenUtility.previousScreen(from: currentScreen) {
                newScreen = previousScreen
            }

            if newAction.direction == .leftScreen,
               let leftScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .left) {
                newScreen = leftScreen
            }

            if newAction.direction == .rightScreen,
               let rightScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .right) {
                newScreen = rightScreen
            }

            if newAction.direction == .topScreen,
               let topScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .top) {
                newScreen = topScreen
            }

            if newAction.direction == .bottomScreen,
               let bottomScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .bottom) {
                newScreen = bottomScreen
            }

            // If the current action is either `.noAction`/`.noSelection`, or `.smaller`/`.larger` etc,
            // then we will preserve the window's proportional frame relative to the current screen on the new screen.
            if resizeContext.action.direction.isNoOp || resizeContext.action.willManipulateExistingWindowFrame {
                if let targetWindow = resizeContext.window {
                    let screenSwitchingCustomActionName = "autogenerated_screen_switching_action"

                    if let lastAction = await WindowRecords.shared.getCurrentAction(for: targetWindow),
                       lastAction.getName() != screenSwitchingCustomActionName,
                       !lastAction.forceProportionalFrameOnScreenChange {
                        setResizeAction(to: lastAction, parent: nil)
                    } else {
                        let currentFrame = targetWindow.frame

                        let adjustedBounds = PaddingConfiguration
                            .getConfiguredPadding(for: currentScreen)
                            .applyToBounds(currentScreen.cgSafeScreenFrame, screen: currentScreen)

                        let proportionalSize = CGRect(
                            x: (currentFrame.minX - adjustedBounds.minX) / adjustedBounds.width,
                            y: (currentFrame.minY - adjustedBounds.minY) / adjustedBounds.height,
                            width: currentFrame.width / adjustedBounds.width,
                            height: currentFrame.height / adjustedBounds.height
                        )

                        setResizeAction(
                            to: .init(
                                .custom,
                                keybind: [],
                                name: screenSwitchingCustomActionName,
                                unit: .percentage,
                                width: proportionalSize.width * 100,
                                height: proportionalSize.height * 100,
                                xPoint: proportionalSize.minX * 100,
                                yPoint: proportionalSize.minY * 100,
                                positionMode: .coordinates,
                                sizeMode: .custom
                            ),
                            parent: nil
                        )
                    }
                } else {
                    setResizeAction(to: .init(.center), parent: nil)
                }
            }

            resizeContext.setScreen(to: newScreen)

            if let parent = newParentAction {
                setResizeAction(to: newAction, parent: newParentAction)
                await changeAction(parent, triggeredFromScreenChange: true)
            } else {
                if !disableHapticFeedback {
                    performHapticFeedback()
                }

                Task {
                    _ = try await WindowActionEngine.shared.apply(context: resizeContext)
                }
            }

            log.info("Screen changed: \(newScreen.localizedName)")

            return
        }

        if !disableHapticFeedback {
            performHapticFeedback()
        }

        if newAction != resizeContext.action || newAction.canRepeat {
            let previousActionWasNoOp = resizeContext.action.direction.isNoOp
            setResizeAction(to: newAction, parent: newParentAction)
            if !previousActionWasNoOp {
                await resizeContext.refreshResolvedState()
            }

            Task {
                // If the action is to focus a window in a specific direction, find and activate that window
                // This can work even without a current window (navigates from screen center)
                if newAction.direction.willFocusWindow {
                    let result = try await WindowActionEngine.shared.apply(context: resizeContext)

                    if let newTargetWindow = result.newTargetWindow {
                        resizeContext.setWindow(to: newTargetWindow)
                    }
                } else {
                    _ = try await WindowActionEngine.shared.apply(context: resizeContext)
                }
            }

            log.info("Window action changed: \(newAction.description)")
        }
    }

    private func getNextCycleAction(_ action: WindowAction) async -> WindowAction {
        guard let currentCycle = action.cycle else {
            return action
        }

        // Allow cycling backwards only if:
        // - Shift is not part of the action's keybind (eligibleForReverseCycle)
        // - Shift is not part of the trigger key
        // - The user has enabled the setting
        let allowReverseCycle = action.eligibleForReverseCycle
            && Defaults[.triggerKey].contains(.kVK_Shift) == false
            && Defaults[.cycleBackwardsOnShiftPressed]

        let shouldCycleBackwards = allowReverseCycle && keybindTrigger.effectiveEventFlags.contains(.maskShift)
        var currentIndex: Int? = nil

        if Defaults[.cycleModeRestartEnabled],
           resizeContext.action.direction == .noSelection || !currentCycle.contains(resizeContext.action) {
            return currentCycle[0]
        }

        // If the current action is noSelection, we can preserve the index from the last action.
        // This would initially be done by reading the window's records, then would continue by finding the next index from the currentAction.
        if resizeContext.action.direction == .noSelection,
           !currentCycle.contains(resizeContext.action),
           let window = resizeContext.window,
           let latestRecord = await WindowRecords.shared.getCurrentAction(for: window) {
            currentIndex = currentCycle.firstIndex(of: latestRecord)
        } else {
            currentIndex = currentCycle.firstIndex(of: resizeContext.action)
        }

        guard var nextIndex = currentIndex else {
            return currentCycle[0]
        }

        nextIndex += shouldCycleBackwards ? -1 : 1

        // Wrap around the cycle index if we've reached the end or gone before the start.
        if nextIndex >= currentCycle.count {
            nextIndex = 0
        }

        if nextIndex < 0 {
            nextIndex = currentCycle.count - 1
        }

        return currentCycle[nextIndex]
    }

    private func performHapticFeedback() {
        if Defaults[.hapticFeedback] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func setResizeAction(to newAction: WindowAction, parent newParentAction: WindowAction?) {
        resizeContext.setAction(to: newAction, parent: newParentAction)
    }

    /// Resolves the target screen for `screenToResizeOn`.
    ///
    /// By default, this uses the user's `useScreenWithCursor` setting.
    /// For actions that move windows between screens, the screen containing the window is preferred to ensure deterministic behavior.
    /// - Parameters:
    ///   - action: The window action being performed.
    ///   - window: The window to be resized, if any.
    /// - Returns: The screen the window should be on after the action.
    private func resolveAndStoreTargetScreen(action: WindowAction, window: Window?) -> NSScreen? {
        var targetScreen = Defaults[.useScreenWithCursor] ? NSScreen.screenWithMouse : NSScreen.main

        if action.direction.willChangeScreen,
           let window,
           let screen = ScreenUtility.screenContaining(window) {
            targetScreen = screen
        }

        resizeContext.setScreen(to: targetScreen)

        return targetScreen
    }
}
