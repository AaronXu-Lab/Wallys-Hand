import Darwin
import Foundation

private final class StatusRecorder {
    private let lock = NSLock()
    private var values: [UUID: PortServiceStatus] = [:]
    func record(_ id: UUID, _ status: PortServiceStatus) {
        lock.lock(); defer { lock.unlock() }
        values[id] = status
    }
    func status(_ id: UUID) -> PortServiceStatus {
        lock.lock(); defer { lock.unlock() }
        return values[id] ?? PortServiceStatus()
    }
}

@main
struct PortRegression {
    static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw PortProcessError.message(message) }
    }
    static func wait(_ message: String, timeout: TimeInterval = 15, _ condition: () throws -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if try condition() { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw PortProcessError.message("Timed out: \(message)")
    }
    static func freePort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(fd) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        try require(result == 0, "Cannot allocate test port")
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &size) }
        }
        return Int(UInt16(bigEndian: address.sin_port))
    }
    static func openDescriptorCount() -> Int {
        (0..<2048).reduce(0) { count, fd in
            errno = 0
            return count + (fcntl(Int32(fd), F_GETFD) >= 0 || errno != EBADF ? 1 : 0)
        }
    }
    static func response(_ port: Int, host: String = "127.0.0.1") throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["--noproxy", "*", "--max-time", "3", "-si", "http://\(host):\(port)"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let recorder = StatusRecorder()
        let supervisor = PortSupervisor(report: recorder.record)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("port-tests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var testServices: [PortService] = []
        defer {
            let stopped = DispatchSemaphore(value: 0)
            supervisor.shutdown { stopped.signal() }
            _ = stopped.wait(timeout: .now() + 15)
            testServices.forEach { try? FileManager.default.removeItem(at: $0.logURL) }
            try? FileManager.default.removeItem(at: directory)
        }
        let suite = "PortTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = PortServiceManager(defaults: defaults)
        let saved = PortService(name: "Saved", port: 54321, directory: directory.path, command: "exit 0")
        try require(manager.save(saved) == nil, "Configuration save failed")
        let restored = PortServiceManager(defaults: defaults)
        try require(restored.services == [saved], "Configuration did not persist")
        try require(!restored.status(saved.id).protected, "Protection persisted across relaunch")
        try require(manager.setAutomaticallyRecover(true, for: saved.id) == nil, "Recovery setting failed")
        try require(PortServiceManager(defaults: defaults).services.first?.automaticallyRecover == true, "Recovery setting did not persist")
        try require(!restored.services[0].isMonitoringLogs, "Old configuration unexpectedly enabled monitoring")
        try require(manager.setMonitorLogs(true, for: saved.id) == nil, "Monitoring setting failed")
        try require(PortServiceManager(defaults: defaults).services.first?.isMonitoringLogs == true, "Monitoring setting did not persist")
        try require(!manager.status(saved.id).protected, "Changing recovery enabled protection")
        let backup = try manager.exportBackup()
        let importSuite = "PortImportTests.\(UUID())"
        let importedDefaults = UserDefaults(suiteName: importSuite)!
        defer { importedDefaults.removePersistentDomain(forName: importSuite) }
        let imported = PortServiceManager(defaults: importedDefaults)
        try imported.importBackup(backup)
        try require(imported.services == manager.services, "Backup did not restore every service setting")
        try require(!imported.status(saved.id).protected, "Import enabled protection")
        do {
            try imported.importBackup(Data("not JSON".utf8))
            throw PortProcessError.message("Invalid backup was accepted")
        } catch is DecodingError {}
        try require(imported.services == manager.services, "Invalid backup changed configuration")
        print("PASS configuration, recovery and monitoring persistence with manual enable on relaunch")
        let descriptorBaseline = openDescriptorCount()
        for _ in 0..<80 { _ = try PortProcess.listeners(port: try freePort()) }
        try require(openDescriptorCount() <= descriptorBaseline + 8, "Port scans leaked file descriptors")
        print("PASS repeated port scans release pipes and child processes")
        let python = CommandLine.arguments[1]
        let server = """
        import http.server, os, socketserver, signal, time
        class Server(socketserver.TCPServer):
            allow_reuse_address = True
        restart = False
        def rebuild(signum, frame):
            global restart
            restart = True
        signal.signal(signal.SIGUSR1, rebuild)
        def create():
            s = Server(('127.0.0.1', int(os.environ['PORT'])), http.server.SimpleHTTPRequestHandler)
            s.timeout = 0.1
            return s
        s = create()
        while True:
            s.handle_request()
            if restart:
                s.server_close()
                time.sleep(1.2)
                s = create()
                restart = False
                open("rebuilt", "w").close()
        """
        try server.write(to: directory.appendingPathComponent("server.py"), atomically: true, encoding: .utf8)
        let port = try freePort()
        var service = PortService(name: "Fixture", port: port, directory: directory.path,
                                  command: "\(python) server.py & child=$!; wait $child")
        testServices.append(service)
        try require(service.validationError(existing: []) == nil, "Valid service rejected")
        var duplicate = service; duplicate.id = UUID()
        try require(duplicate.validationError(existing: [service]) != nil, "Duplicate port accepted")
        try require(recorder.status(service.id).phase == .disabled, "Unexpected automatic enable")

        // A foreign fixture is the only external process this test authorizes reclaiming.
        var foreignService = service
        foreignService.command = "trap '' TERM; " + service.command
        let foreign = try PortProcess(service: foreignService)
        defer { try? foreign.terminate(force: true); foreign.refresh() }
        try wait("foreign fixture listening") { !(try PortProcess.listeners(port: port)).isEmpty }
        let foreignOwners = try PortProcess.listeners(port: port)
        supervisor.enable(service)
        try wait("foreign port reclaimed and expected service running") { recorder.status(service.id).phase == .running }
        try require(foreignOwners.allSatisfy { !$0.alive }, "Foreign process was not reclaimed")
        print("PASS external port reclamation (including SIGKILL) and descendant ownership")

        let rebuilding = try PortProcess.listeners(port: port)
        for owner in rebuilding { try owner.signal(SIGUSR1) }
        try wait("short rebuild finished") { FileManager.default.fileExists(atPath: directory.appendingPathComponent("rebuilt").path) }
        try wait("same process recovered") { recorder.status(service.id).phase == .running }
        try require(try PortProcess.listeners(port: port) == rebuilding, "Brief rebuild restarted the service")
        print("PASS short rebuild keeps the original process")

        for owner in try PortProcess.listeners(port: port) { try owner.signal(SIGKILL) }
        try wait("failed service") { recorder.status(service.id).phase == .failed }
        try wait("HTTP placeholder") { try response(port).contains("503 Service Unavailable") }
        try require(try response(port, host: "[::1]").contains("503 Service Unavailable"), "Missing IPv6 placeholder")
        Thread.sleep(forTimeInterval: 3)
        try require(recorder.status(service.id).phase == .failed, "Auto recovery enabled by default")
        print("PASS crash notification, IPv4/IPv6 placeholder, default manual recovery")

        supervisor.retry(service.id)
        try wait("manual retry") { recorder.status(service.id).phase == .running }
        supervisor.stop(service.id, disable: false)
        try wait("stop keeps placeholder") { try response(port).contains("503 Service Unavailable") }
        try require(recorder.status(service.id).protected, "Stop released protection")
        supervisor.stop(service.id, disable: true)
        try wait("disable releases port") {
            try recorder.status(service.id).phase == .disabled && PortProcess.listeners(port: port).isEmpty
        }
        print("PASS manual retry, stop preserves protection, disable releases port")

        service.id = UUID(); service.automaticallyRecover = false
        testServices.append(service)
        supervisor.enable(service)
        try wait("automatic service running") { recorder.status(service.id).phase == .running }
        let before = try PortProcess.listeners(port: port)
        supervisor.setAutomaticallyRecover(true, for: service.id)
        Thread.sleep(forTimeInterval: 0.7)
        try require(try PortProcess.listeners(port: port) == before, "Toggling recovery restarted a running service")
        for owner in before { try owner.signal(SIGKILL) }
        try wait("automatic recovery", timeout: 20) {
            let listeners = try PortProcess.listeners(port: port)
            return recorder.status(service.id).phase == .running && !listeners.isEmpty && listeners.isDisjoint(with: before)
        }
        print("PASS enabling recovery at runtime without restarting the process")
        supervisor.setAutomaticallyRecover(false, for: service.id)
        Thread.sleep(forTimeInterval: 0.7)
        for owner in try PortProcess.listeners(port: port) { try owner.signal(SIGKILL) }
        try wait("runtime recovery disabled") { recorder.status(service.id).phase == .failed }
        try wait("disabled recovery placeholder") { try response(port).contains("503 Service Unavailable") }
        supervisor.setAutomaticallyRecover(true, for: service.id)
        try wait("enabling recovery while failed", timeout: 20) { recorder.status(service.id).phase == .running }
        print("PASS disabling recovery affects the next failure; enabling recovers an already failed service")
        supervisor.stop(service.id, disable: false)
        try wait("automatic service intentionally stopped") { try response(port).contains("503 Service Unavailable") }
        supervisor.setAutomaticallyRecover(false, for: service.id)
        supervisor.setAutomaticallyRecover(true, for: service.id)
        Thread.sleep(forTimeInterval: 4)
        try require(recorder.status(service.id).phase == .stopped, "Intentional stop triggered recovery")
        supervisor.retry(service.id)
        try wait("retry before shutdown") { recorder.status(service.id).phase == .running }
        let owned = try PortProcess.listeners(port: port)
        let done = DispatchSemaphore(value: 0)
        supervisor.shutdown { done.signal() }
        try require(done.wait(timeout: .now() + 15) == .success, "Shutdown stalled")
        try require(owned.allSatisfy { !$0.alive }, "Shutdown left child processes")
        try require(try PortProcess.listeners(port: port).isEmpty, "Shutdown left listeners")
        print("PASS explicit stop suppresses recovery; shutdown cleans children and sockets")

        let fast = PortSupervisor(timing: .init(poll: 0.05, interruptionGrace: 0.15,
                                               startupTimeout: 0.5, retryBase: 0.1, retryLimit: 2),
                                  report: recorder.record)
        defer {
            let finished = DispatchSemaphore(value: 0)
            fast.shutdown { finished.signal() }
            _ = finished.wait(timeout: .now() + 10)
        }
        var failing = PortService(name: "Failure", port: try freePort(), directory: directory.path,
                                  command: "echo attempt; echo attempt >> attempts; exit 23", automaticallyRecover: true,
                                  monitorLogs: true)
        testServices.append(failing)
        fast.enable(failing)
        try wait("retry limit") { recorder.status(failing.id).phase == .failed }
        let attempts = try String(contentsOf: directory.appendingPathComponent("attempts"), encoding: .utf8)
        try require(attempts.split(separator: "\n").count == 3, "Wrong retry limit")
        let monitoredLog = try String(contentsOf: failing.logURL, encoding: .utf8)
        try require(monitoredLog.components(separatedBy: "\nattempt\n").count - 1 == 3,
                    "Monitoring did not preserve output from all attempts")
        try require(monitoredLog.contains("退出码 23") && monitoredLog.contains("状态：等待重试") &&
                    monitoredLog.contains("已达到 2 次重试上限"),
                    "Monitoring did not preserve lifecycle events")
        try wait("exhausted retries keep placeholder") { try response(failing.port).contains("503 Service Unavailable") }
        fast.stop(failing.id, disable: true)
        try wait("failed service disabled") { recorder.status(failing.id).phase == .disabled }
        print("PASS bounded retries and placeholder after exhaustion")

        failing.id = UUID(); failing.command = "sleep 60"; failing.automaticallyRecover = false
        testServices.append(failing)
        fast.enable(failing)
        try wait("startup timeout") { recorder.status(failing.id).phase == .failed }
        try wait("startup timeout placeholder") { try response(failing.port).contains("503 Service Unavailable") }
        fast.retry(failing.id)
        fast.stop(failing.id, disable: true)
        // A stale Stop command must not turn protection back on after Disable.
        fast.stop(failing.id, disable: false)
        try wait("rapid retry/disable cleanup") {
            try recorder.status(failing.id).phase == .disabled && PortProcess.listeners(port: failing.port).isEmpty
        }
        print("PASS startup timeout and rapid action cancellation")

        let cancellable = PortSupervisor(timing: .init(poll: 0.05, interruptionGrace: 0.15,
                                                      startupTimeout: 0.5, retryBase: 2, retryLimit: 2),
                                         report: recorder.record)
        defer {
            let finished = DispatchSemaphore(value: 0)
            cancellable.shutdown { finished.signal() }
            _ = finished.wait(timeout: .now() + 10)
        }
        let pending = PortService(name: "Cancel retry", port: try freePort(), directory: directory.path,
                                  command: "echo attempt >> cancelled-attempts; exit 23", automaticallyRecover: true)
        testServices.append(pending)
        cancellable.enable(pending)
        try wait("retry scheduled") { recorder.status(pending.id).phase == .retrying }
        cancellable.setAutomaticallyRecover(false, for: pending.id)
        try wait("retry cancelled immediately") { recorder.status(pending.id).phase == .failed }
        Thread.sleep(forTimeInterval: 3)
        let cancelledAttempts = try String(contentsOf: directory.appendingPathComponent("cancelled-attempts"), encoding: .utf8)
        try require(cancelledAttempts.split(separator: "\n").count == 1, "Cancelled retry still launched")
        try require(try response(pending.port).contains("503 Service Unavailable"), "Cancelled retry released protection")
        print("PASS turning recovery off cancels pending retries and keeps protection")
    }
}
