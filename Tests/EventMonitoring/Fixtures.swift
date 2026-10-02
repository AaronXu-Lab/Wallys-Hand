// Minimal app model; the runner compiles the real timer, cache and event-monitor sources.
import AppKit
import Defaults

struct WindowAction: Codable, Equatable, Defaults.Serializable {
    enum Direction: String, Codable { case noSelection, left, right, cycle }
    var id = UUID()
    var direction: Direction
    var keybind: Set<CGKeyCode>
    var bypassTriggerKey: Bool?

    init(_ direction: Direction, keybind: Set<CGKeyCode> = [], bypassTriggerKey: Bool? = nil) {
        self.direction = direction
        self.keybind = keybind
        self.bypassTriggerKey = bypassTriggerKey
    }
}

extension UInt16 {
    static let kVK_Shift: UInt16 = 0x38
}

extension Bundle {
    var bundleID: String { "com.xuweinan.LoopJust.EventMonitoringRegression" }
}

extension Defaults.Keys {
    static let testSuiteName = "LoopJust.EventMonitoringRegression.\(UUID().uuidString)"
    static let testSuite = UserDefaults(suiteName: testSuiteName)!
    static let keybinds = Key<[WindowAction]>("keybinds", default: [], suite: testSuite)
}
