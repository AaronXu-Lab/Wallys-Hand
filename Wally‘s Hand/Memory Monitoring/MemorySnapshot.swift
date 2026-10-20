import Foundation

struct MemorySnapshot: Sendable {
    enum Pressure: Sendable {
        case normal, warning, critical, unknown

        init(rawValue: Int32?) {
            switch rawValue {
            case 1: self = .normal
            case 2: self = .warning
            case 4: self = .critical
            default: self = .unknown
            }
        }
    }

    struct Process: Identifiable, Sendable {
        let id: Int32
        let name: String
        let bytes: UInt64
    }

    let uptime: TimeInterval
    let swapInBytes: UInt64
    let swapOutBytes: UInt64
    let date: Date
    let total: UInt64
    let used: UInt64
    let compressed: UInt64
    let swapUsed: UInt64?
    let pressure: Pressure
    let processes: [Process]
    let unreadableProcesses: Int

    var fraction: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }

    // Active + inactive includes file cache. Remove external (file-backed) pages
    // and reclaimable purgeable pages, then add wired and the compressor's size.
    static func usedBytes(active: UInt64, inactive: UInt64, wired: UInt64,
                          compressed: UInt64, external: UInt64, purgeable: UInt64,
                          pageSize: UInt64, total: UInt64) -> UInt64 {
        let occupied = active + inactive + wired + compressed
        let reclaimable = external + purgeable
        return min(total, (occupied > reclaimable ? occupied - reclaimable : 0) * pageSize)
    }
}

struct MemorySwapRate: Sendable {
    let incoming: Double
    let outgoing: Double
    let interval: TimeInterval

    init?(previous: MemorySnapshot, current: MemorySnapshot) {
        let elapsed = current.uptime - previous.uptime
        // Sleeping, failed reads and a reopened page must not look like a current rate.
        guard elapsed > 0, elapsed <= 20,
              current.swapInBytes >= previous.swapInBytes,
              current.swapOutBytes >= previous.swapOutBytes else { return nil }
        incoming = Double(current.swapInBytes - previous.swapInBytes) / elapsed
        outgoing = Double(current.swapOutBytes - previous.swapOutBytes) / elapsed
        interval = elapsed
    }
}
