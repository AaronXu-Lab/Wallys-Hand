import Darwin
import Foundation

/// Runs serially outside the main actor; no shell processes or elevated access.
actor MemorySampler {
    func sample() throws -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { throw SampleError.unavailable }
        let total = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(vm_kernel_page_size)
        let used = MemorySnapshot.usedBytes(
            active: UInt64(stats.active_count), inactive: UInt64(stats.inactive_count),
            wired: UInt64(stats.wire_count), compressed: UInt64(stats.compressor_page_count),
            external: UInt64(stats.external_page_count), purgeable: UInt64(stats.purgeable_count),
            pageSize: pageSize, total: total)
        var pressure: Int32 = 0
        let hasPressure = readSysctl("kern.memorystatus_vm_pressure_level", into: &pressure)
        var swap = xsw_usage()
        let hasSwap = readSysctl("vm.swapusage", into: &swap)
        let processes = try topProcesses()
        return MemorySnapshot(uptime: ProcessInfo.processInfo.systemUptime,
                              swapInBytes: stats.swapins * pageSize,
                              swapOutBytes: stats.swapouts * pageSize,
                              date: Date(), total: total, used: used,
                              compressed: UInt64(stats.compressor_page_count) * pageSize,
                              swapUsed: hasSwap ? swap.xsu_used : nil,
                              pressure: .init(rawValue: hasPressure ? pressure : nil),
                              processes: processes.rows, unreadableProcesses: processes.skipped)
    }

    private func readSysctl<T>(_ name: String, into value: inout T) -> Bool {
        var size = MemoryLayout<T>.size
        return withUnsafeMutablePointer(to: &value) {
            sysctlbyname(name, $0, &size, nil, 0) == 0
        }
    }

    private func topProcesses() throws -> (rows: [MemorySnapshot.Process], skipped: Int) {
        let estimated = proc_listallpids(nil, 0)
        guard estimated > 0 else { throw SampleError.unavailable }
        var pids = [pid_t](repeating: 0, count: Int(estimated) + 256)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard count > 0 else { throw SampleError.unavailable }
        var rows: [MemorySnapshot.Process] = []
        var skipped = 0
        for pid in pids.prefix(min(Int(count), pids.count)) where pid > 0 {
            var usage = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
                }
            }
            guard result == 0 else { skipped += 1; continue }
            var name = [CChar](repeating: 0, count: 1024)
            let length = name.withUnsafeMutableBytes { proc_name(pid, $0.baseAddress, UInt32($0.count)) }
            rows.append(.init(id: pid, name: length > 0 ? String(cString: name) : "PID \(pid)",
                              bytes: usage.ri_phys_footprint))
        }
        rows.sort { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }
        return (Array(rows.prefix(5)), skipped)
    }

    enum SampleError: LocalizedError {
        case unavailable
        var errorDescription: String? { "暂时无法读取内存信息，将在 10 秒后重试。" }
    }
}
