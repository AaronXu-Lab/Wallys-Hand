import Foundation

@main
struct MemoryMonitoringRegression {
    static func main() async throws {
        precondition(MemorySnapshot.Pressure(rawValue: 1) == .normal)
        precondition(MemorySnapshot.Pressure(rawValue: 2) == .warning)
        precondition(MemorySnapshot.Pressure(rawValue: 4) == .critical)
        precondition(MemorySnapshot.Pressure(rawValue: nil) == .unknown)
        precondition(MemorySnapshot.Pressure(rawValue: 99) == .unknown)
        precondition(MemorySnapshot.usedBytes(active: 100, inactive: 50, wired: 25,
                                             compressed: 20, external: 60, purgeable: 5,
                                             pageSize: 16384, total: 10_000_000) == 130 * 16384)
        precondition(MemorySnapshot.usedBytes(active: 1, inactive: 0, wired: 0,
                                             compressed: 0, external: 2, purgeable: 0,
                                             pageSize: 4096, total: 100) == 0)
        precondition(MemorySnapshot.usedBytes(active: 100, inactive: 0, wired: 0,
                                             compressed: 0, external: 0, purgeable: 0,
                                             pageSize: 4096, total: 100) == 100)
        func sample(_ uptime: Double, _ incoming: UInt64, _ outgoing: UInt64) -> MemorySnapshot {
            MemorySnapshot(uptime: uptime, swapInBytes: incoming, swapOutBytes: outgoing,
                           date: Date(), total: 24, used: 20, compressed: 7, swapUsed: 18,
                           pressure: .normal, processes: [], unreadableProcesses: 0)
        }
        let baseline = sample(100, 1000, 2000)
        let rate = MemorySwapRate(previous: baseline, current: sample(110, 3000, 6000))!
        precondition(rate.incoming == 200 && rate.outgoing == 400 && rate.interval == 10)
        precondition(MemorySwapRate(previous: baseline, current: sample(110, 1000, 2000))!.incoming == 0)
        precondition(MemorySwapRate(previous: baseline, current: sample(100, 3000, 6000)) == nil)
        precondition(MemorySwapRate(previous: baseline, current: sample(130, 3000, 6000)) == nil)
        precondition(MemorySwapRate(previous: baseline, current: sample(110, 0, 6000)) == nil)
        let sampler = MemorySampler()
        let first = try await sampler.sample()
        try await Task.sleep(for: .seconds(10))
        let second = try await sampler.sample()
        precondition(second.date.timeIntervalSince(first.date) >= 10)
        for sample in [first, second] {
            precondition(sample.total == ProcessInfo.processInfo.physicalMemory)
            precondition(sample.used > 0 && sample.used <= sample.total)
            precondition(sample.compressed <= sample.total)
            precondition(sample.swapUsed != nil)
            precondition(!sample.processes.isEmpty && sample.processes.count <= 5)
            precondition(Set(sample.processes.map(\.id)).count == sample.processes.count)
            precondition(sample.processes.map(\.bytes) == sample.processes.map(\.bytes).sorted(by: >))
            print("Snapshot: used=\(sample.used), compressed=\(sample.compressed), swap=\(sample.swapUsed!), pressure=\(sample.pressure)")
            for process in sample.processes { print("\(process.id) \(process.name): \(process.bytes)") }
        }
        print("Memory monitoring regression checks passed")
    }
}
