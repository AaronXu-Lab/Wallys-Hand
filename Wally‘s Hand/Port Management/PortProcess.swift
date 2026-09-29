import Darwin
import Foundation

/// PID plus kernel start time: never signal a PID that has since been reused.
struct PortProcessIdentity: Hashable {
    let pid: pid_t
    let seconds: UInt64
    let microseconds: UInt64

    init?(_ pid: pid_t) {
        guard let info = Self.info(pid) else { return nil }
        self.pid = pid
        seconds = info.pbi_start_tvsec
        microseconds = info.pbi_start_tvusec
    }

    static func info(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    var alive: Bool { PortProcessIdentity(pid) == self }

    func signal(_ value: Int32) throws {
        guard alive else { return }
        guard pid > 1, pid != getpid() else { throw PortProcessError.message("无法终止应用自身或系统初始化进程。") }
        if Darwin.kill(pid, value) != 0 && errno != ESRCH {
            throw PortProcessError.message("无法终止 PID \(pid)：\(String(cString: strerror(errno)))")
        }
    }
}

enum PortProcessError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(message) = self { return message }; return nil }
}

final class PortProcess {
    let pid: pid_t
    private var members: Set<PortProcessIdentity> = []
    private var reaped = false
    private(set) var exitSummary: String?

    init(service: PortService) throws {
        try FileManager.default.createDirectory(at: service.logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Monitoring preserves every attempt; normal logging retains only the latest attempt.
        let log = open(service.logURL.path, O_WRONLY | O_CREAT | O_APPEND |
                       (service.isMonitoringLogs ? 0 : O_TRUNC), S_IRUSR | S_IWUSR)
        guard log >= 0 else { throw PortProcessError.message("无法创建服务日志。") }
        defer { close(log) }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, log, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, log, STDERR_FILENO)
        if #available(macOS 26, *) {
            posix_spawn_file_actions_addchdir(&actions, service.expandedDirectory)
        } else {
            posix_spawn_file_actions_addchdir_np(&actions, service.expandedDirectory)
        }
        // Dispatch workers can block signals. Do not pass that mask to development servers:
        // it would prevent graceful termination and tools' own rebuild signals.
        var signalMask = sigset_t()
        var signalDefaults = sigset_t()
        sigemptyset(&signalMask)
        sigfillset(&signalDefaults)
        sigdelset(&signalDefaults, SIGKILL)
        sigdelset(&signalDefaults, SIGSTOP)
        posix_spawnattr_setsigmask(&attributes, &signalMask)
        posix_spawnattr_setsigdefault(&attributes, &signalDefaults)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT |
                                                    POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
        posix_spawnattr_setpgroup(&attributes, 0)
        let args = ["/bin/zsh", "-l", "-c", service.command].map { strdup($0) } + [nil]
        var environment = ProcessInfo.processInfo.environment
        environment["PORT"] = String(service.port)
        let env = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { args.forEach { free($0) }; env.forEach { free($0) } }
        var child: pid_t = 0
        let result = args.withUnsafeBufferPointer { argv in
            env.withUnsafeBufferPointer { envp in
                posix_spawn(&child, "/bin/zsh", &actions, &attributes, argv.baseAddress!, envp.baseAddress!)
            }
        }
        guard result == 0 else { throw PortProcessError.message("启动失败：\(String(cString: strerror(result)))") }
        pid = child
        if let identity = PortProcessIdentity(child) { members.insert(identity) }
    }

    func refresh() {
        // Keep the group anchored to a known living identity before discovering descendants.
        if members.contains(where: \.alive) {
            let bytes = proc_listallpids(nil, 0) * Int32(MemoryLayout<pid_t>.size) + 4096
            var pids = [pid_t](repeating: 0, count: Int(bytes) / MemoryLayout<pid_t>.size)
            let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
            for candidate in pids.prefix(max(0, Int(count))) where candidate > 1 {
                if let info = PortProcessIdentity.info(candidate), info.pbi_pgid == UInt32(pid),
                   let identity = PortProcessIdentity(candidate) { members.insert(identity) }
            }
        }
        if !reaped {
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == pid {
                reaped = true
                let signal = status & 0x7f
                exitSummary = signal == 0 ? "退出码 \((status >> 8) & 0xff)" : "被信号 \(signal) 终止"
            }
        }
        members = members.filter(\.alive)
    }

    func owns(_ identity: PortProcessIdentity) -> Bool { members.contains(identity) && identity.alive }
    var alive: Bool { members.contains(where: \.alive) }

    func terminate(force: Bool = false) throws {
        refresh()
        for member in members { try member.signal(force ? SIGKILL : SIGTERM) }
    }

    static func listeners(port: Int) throws -> Set<PortProcessIdentity> {
        let process = Process()
        let output = Pipe()
        defer {
            output.fileHandleForReading.closeFile()
            output.fileHandleForWriting.closeFile()
        }
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        // The parent must release its writer or the pipe can outlive lsof.
        output.fileHandleForWriting.closeFile()
        // lsof can stall on system inspection; bound it without blocking the UI thread.
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        if process.isRunning {
            process.terminate()
            Darwin.kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
            throw PortProcessError.message("端口检查超时。")
        }
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 || process.terminationStatus == 1 else {
            throw PortProcessError.message("无法检查端口占用。")
        }
        return Set(String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
            .compactMap { Int32($0) }.compactMap(PortProcessIdentity.init))
    }
}
