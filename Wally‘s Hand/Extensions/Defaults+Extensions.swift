//
//  Defaults+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//
// NOTE: While iCloud is enabled, its service is currently disabled to make GitHub actions work.

import Defaults
import SwiftUI

// MARK: - UI-configurable Settings

extension Defaults.Keys {
    static let timesLooped = Key<Int>("timesLooped", default: 0, iCloud: true)
    static let showDockIcon = Key<Bool>("showDockIcon", default: false, iCloud: true)

    // Behavior
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false, iCloud: true)
    static let startHidden = Key<Bool>("startHidden", default: false, iCloud: true)
    static let windowManagementEnabled = Key<Bool>("windowManagementEnabled", default: false, iCloud: false)
    static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false, iCloud: false)
    static let windowSnapping = Key<Bool>("windowSnapping", default: false, iCloud: true)
    static let suppressMissionControlOnTopDrag = Key<Bool>("suppressMissionControlOnTopDrag", default: true, iCloud: true)
    static let restoreWindowFrameOnDrag = Key<Bool>("restoreWindowFrameOnDrag", default: false, iCloud: true)
    static let enablePadding = Key<Bool>("enablePadding", default: false, iCloud: true)
    static let padding = Key<PaddingConfiguration>("padding", default: .zero, iCloud: true)
    static let useScreenWithCursor = Key<Bool>("useScreenWithCursor", default: true, iCloud: true)
    static let moveCursorWithWindow = Key<Bool>("moveCursorWithWindow", default: false, iCloud: true)
    static let resizeWindowUnderCursor = Key<Bool>("resizeWindowUnderCursor", default: false, iCloud: true)
    static let focusWindowOnResize = Key<Bool>("focusWindowOnResize", default: true, iCloud: true)
    static let respectStageManager = Key<Bool>("respectStageManager", default: true, iCloud: true)
    static let stageStripSize = Key<CGFloat>("stageStripSize", default: 150, iCloud: true)
    static let cycleModeRestartEnabled = Key<Bool>("cycleModeRestartEnabled", default: false, iCloud: true)

    // Keybinds
    static let triggerKey = Key<Set<CGKeyCode>>("trigger", default: [.kVK_Function], iCloud: true)
    static let sideDependentTriggerKey = Key<Bool>("sideDependentTriggerKey", default: true, iCloud: true)
    static let triggerDelay = Key<Double>("triggerDelay", default: 0, iCloud: true)
    static let doubleClickToTrigger = Key<Bool>("doubleClickToTrigger", default: false, iCloud: true)
    static let cycleBackwardsOnShiftPressed = Key<Bool>("cycleBackwardsOnShiftPressed", default: true, iCloud: true)
    static let keybinds = Key<[WindowAction]>("keybinds", default: WindowAction.defaultKeybinds, iCloud: true)

    // Advanced
    static let useSystemWindowManagerWhenAvailable = Key<Bool>("useSystemWindowManagerWhenAvailable", default: false, iCloud: true)
    static let animateWindowResizes = Key<Bool>("animateWindowResizes", default: false, iCloud: true)
    static let ignoreFullscreen = Key<Bool>("ignoreFullscreen", default: false, iCloud: true)
    static let hapticFeedback = Defaults.Key<Bool>("hapticFeedback", default: true, iCloud: true)
    static let sizeIncrement = Key<CGFloat>("sizeIncrement", default: 20, iCloud: true)

    /// Excluded apps
    static let excludedApps = Key<[URL]>("excludedApps", default: [], iCloud: true)

    // About
    #if RELEASE
        static let includeDevelopmentVersions = Key<Bool>("includeDevelopmentVersions", default: false, iCloud: true)
    #else
        /// Development versions should check for development updates by default.
        static let includeDevelopmentVersions = Key<Bool>("includeDevelopmentVersions", default: true, iCloud: true)
    #endif
}

// MARK: - Hidden Settings

extension Defaults.Keys {
    /// Minimum screen size, defined in inches on the diagonal, for which padding will be applied on windows.
    /// Adjust with `defaults write com.xuweinan.LoopJust paddingMinimumScreenSize -float x`
    /// Reset with `defaults delete com.xuweinan.LoopJust paddingMinimumScreenSize`
    static let paddingMinimumScreenSize = Key<CGFloat>("paddingMinimumScreenSize", default: 0, iCloud: true)

    /// Ignore the notch height when calculating top padding, so the effective
    /// distance from the screen top matches non-notch displays.
    /// Adjust with `defaults write com.xuweinan.LoopJust ignoreNotch -bool true`
    /// Reset with `defaults delete com.xuweinan.LoopJust ignoreNotch`
    static let ignoreNotch = Key<Bool>("ignoreNotch", default: false, iCloud: true)

    /// Snap threshold for window snapping, defined in points.
    /// Adjust with `defaults write com.xuweinan.LoopJust snapThreshold -float x`
    /// Reset with `defaults delete com.xuweinan.LoopJust snapThreshold`
    static let snapThreshold = Key<CGFloat>("snapThreshold", default: 2, iCloud: true)

    /// Whether to ignore low power mode for certain features, such as window animations.
    /// Adjust with `defaults write com.xuweinan.LoopJust ignoreLowPowerMode -bool x`
    /// Reset with `defaults delete com.xuweinan.LoopJust ignoreLowPowerMode`
    static let ignoreLowPowerMode = Key<Bool>("ignoreLowPowerMode", default: false, iCloud: true)

    /// Disable update checks with `defaults write com.xuweinan.LoopJust updatesEnabled -bool false`
    /// Reset with `defaults delete com.xuweinan.LoopJust updatesEnabled`
    static let updatesEnabled = Key<Bool>("updatesEnabled", default: true, iCloud: true)

    /// Trigger key timeout, defined in seconds. Automatically closes Wally‘s Hand if no action is taken within the specified time.
    /// When set to 0 (default: disabled), the feature is disabled and Wally‘s Hand stays open until manually closed.
    /// Adjust with `defaults write com.xuweinan.LoopJust triggerKeyTimeout -float x`
    /// Reset with `defaults delete com.xuweinan.LoopJust triggerKeyTimeout`
    static let triggerKeyTimeout = Key<Double>("triggerKeyTimeout", default: 0, iCloud: true)

    // Migrator

    static let lastMigratorURL = Key<URL?>("lastMigratorURL", default: nil)





}
