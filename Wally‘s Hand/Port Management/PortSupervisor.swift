import Foundation

/// One serial queue owns processes, sockets, timers and all lifecycle transitions.
final class PortSupervisor {
    struct Timing {
        var poll: TimeInterval = 0.5
        var interruptionGrace: TimeInterval = 3
        var startupTimeout: TimeInterval = 90
        var retryBase: TimeInterval = 2
        var retryLimit = 10
    }
    private let timing: Timing

    private final class Runtime {
        var service: PortService
        var enabled = true
        var startRequested = true
        var automaticStartRequested = false
        var failureMessage: String?
        var process: PortProcess?
        var stoppingSince: Date?
        var placeholder: PortPlaceholder?
        var releasingPlaceholder = false
        var startedAt = Date()
        var missingSince: Date?
        var stableSince: Date?
        var hasListened = false
        var idleStatus = PortServiceStatus(phase: .stopped, protected: true)
        var retryAt: Date?
        var retries = 0
        var foreign: [PortProcessIdentity: Date] = [:]
        var status = PortServiceStatus(phase: .starting, protected: true)
        init(_ service: PortService) { self.service = service }
    }

    private let queue = DispatchQueue(label: "com.xuweinan.LoopJust.ports", qos: .utility)
    private var runtimes: [UUID: Runtime] = [:]
    private var timer: DispatchSourceTimer?
    private let report: (UUID, PortServiceStatus) -> Void
    private var shutdownCompletion: (() -> Void)?
    private var shuttingDown = false

    init(timing: Timing = Timing(), report: @escaping (UUID, PortServiceStatus) -> Void) {
        self.timing = timing
        self.report = report
    }

    func enable(_ service: PortService) {
        queue.async {
            guard !self.shuttingDown, self.runtimes[service.id] == nil else { return }
            self.runtimes[service.id] = Runtime(service)
            service.appendMonitorEvent("端口保护已启用，准备启动服务（端口 \(service.port)）。")
            self.report(service.id, PortServiceStatus(phase: .starting, protected: true))
            self.ensureTimer()
            self.tick()
        }
    }

    func setAutomaticallyRecover(_ enabled: Bool, for id: UUID) {
        queue.async {
            guard !self.shuttingDown, let run = self.runtimes[id], run.enabled,
                  run.service.automaticallyRecover != enabled else { return }
            run.service.automaticallyRecover = enabled
            if !enabled, run.retryAt != nil || run.automaticStartRequested {
                // Cancel only automatic work; a manual retry or an already running process continues.
                run.retryAt = nil
                if run.automaticStartRequested { run.startRequested = false }
                run.automaticStartRequested = false
                let message = run.failureMessage ?? "服务暂不可用。"
                run.idleStatus = PortServiceStatus(phase: .failed, detail: message + "自动恢复已关闭，请手动重试。", protected: true)
                self.publish(run, run.idleStatus.phase, run.idleStatus.detail)
            } else if enabled, let message = run.failureMessage,
                      !run.startRequested, run.retryAt == nil,
                      run.process == nil || run.stoppingSince != nil {
                // Opting in while failed starts a fresh recovery budget. Explicit Stop clears the failure.
                run.retries = 0
                self.scheduleRecovery(run, message)
            }
        }
    }

    func setMonitorLogs(_ enabled: Bool, for id: UUID) {
        queue.async {
            guard let run = self.runtimes[id] else { return }
            if !enabled { run.service.appendMonitorEvent("监听日志已关闭。") }
            run.service.monitorLogs = enabled
            if enabled {
                run.service.appendMonitorEvent("监听日志已开启；当前状态：\(run.status.phase.rawValue)；端口：\(run.service.port)。")
            }
        }
    }

    func retry(_ id: UUID) {
        queue.async {
            guard !self.shuttingDown, let run = self.runtimes[id], run.enabled else { return }
            run.retries = 0
            run.retryAt = nil
            run.startRequested = true
            run.automaticStartRequested = false
            run.failureMessage = nil
            self.beginStopping(run)
            self.publish(run, .starting, "正在重新启动服务。")
        }
    }

    func stop(_ id: UUID, disable: Bool) {
        queue.async {
            guard let run = self.runtimes[id] else { return }
            guard run.enabled else { return }
            run.enabled = !disable
            run.startRequested = false
            run.automaticStartRequested = false
            run.failureMessage = nil
            run.retryAt = nil
            self.beginStopping(run)
            run.idleStatus = PortServiceStatus(phase: .stopped, protected: true)
            self.publish(run, .stopped, disable ? "正在停止服务并释放端口。" : "正在停止服务，端口将继续受到保护。")
        }
    }

    func shutdown(completion: @escaping () -> Void) {
        queue.async {
            self.shuttingDown = true
            self.shutdownCompletion = completion
            for run in self.runtimes.values {
                run.enabled = false
                run.startRequested = false
                run.retryAt = nil
                self.beginStopping(run)
            }
            self.ensureTimer()
            self.tick()
        }
    }

    private func ensureTimer() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: timing.poll, leeway: .milliseconds(20))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }

    private func publish(_ run: Runtime, _ phase: PortServiceStatus.Phase, _ detail: String = "") {
        let status = PortServiceStatus(phase: phase, detail: detail, protected: true)
        guard status != run.status else { return }
        run.status = status
        run.service.appendMonitorEvent("状态：\(phase.rawValue)\(detail.isEmpty ? "" : "；\(detail)")")
        report(run.service.id, status)
    }

    private func beginStopping(_ run: Runtime) {
        guard run.process != nil, run.stoppingSince == nil else { return }
        run.stoppingSince = Date()
        do { try run.process?.terminate() }
        catch { publish(run, .conflict, error.localizedDescription) }
    }

    private func tick() {
        for run in Array(runtimes.values) {
            do { try tick(run) }
            catch { publish(run, .conflict, error.localizedDescription) }
        }
        if runtimes.isEmpty {
            timer?.cancel()
            timer = nil
            if let completion = shutdownCompletion {
                shutdownCompletion = nil
                completion()
            }
        }
    }

    private func tick(_ run: Runtime) throws {
        run.process?.refresh()
        if let stopping = run.stoppingSince {
            if run.process?.alive == true {
                if Date().timeIntervalSince(stopping) >= 2 { try run.process?.terminate(force: true) }
                return
            }
            run.process = nil
            run.stoppingSince = nil
        }
        guard run.enabled else {
            if run.placeholder != nil { releasePlaceholder(run); return }
            guard !run.releasingPlaceholder else { return }
            runtimes.removeValue(forKey: run.service.id)
            report(run.service.id, PortServiceStatus())
            return
        }
        guard !run.releasingPlaceholder else { return }

        let listeners = try PortProcess.listeners(port: run.service.port)
        let foreign = listeners.filter {
            $0.pid != getpid() && run.process?.owns($0) != true
        }
        run.foreign = run.foreign.filter { foreign.contains($0.key) }
        if !foreign.isEmpty {
            for owner in foreign {
                let firstSeen = run.foreign[owner] ?? Date()
                run.foreign[owner] = firstSeen
                try owner.signal(Date().timeIntervalSince(firstSeen) >= 2 ? SIGKILL : SIGTERM)
            }
            publish(run, .conflict, "正在回收端口，占用进程：\(foreign.map { String($0.pid) }.sorted().joined(separator: ", "))")
            return
        }

        if let process = run.process {
            let listening = listeners.contains { process.owns($0) }
            if listening {
                run.missingSince = nil
                run.hasListened = true
                if run.stableSince == nil { run.stableSince = Date() }
                if Date().timeIntervalSince(run.stableSince!) >= 120 { run.retries = 0 }
                publish(run, .running)
            } else {
                run.stableSince = nil
                if run.missingSince == nil { run.missingSince = Date() }
                let wasStarting = !run.hasListened
                let expired = wasStarting
                    ? Date().timeIntervalSince(run.startedAt) >= timing.startupTimeout
                    : Date().timeIntervalSince(run.missingSince!) >= timing.interruptionGrace
                if expired || (!process.alive && Date().timeIntervalSince(run.missingSince!) >= timing.interruptionGrace) {
                    fail(run, "服务已退出或未监听指定端口。")
                } else if !wasStarting {
                    publish(run, .interrupted, "端口暂时断开，等待服务自行恢复。")
                }
            }
            return
        }

        if let retryAt = run.retryAt, Date() >= retryAt {
            run.retryAt = nil
            run.startRequested = true
            run.automaticStartRequested = true
        }
        if run.startRequested {
            if run.placeholder != nil { releasePlaceholder(run); return }
            // A socket from our cancelled placeholder must be fully closed before spawning.
            guard !listeners.contains(where: { $0.pid == getpid() }) else {
                throw PortProcessError.message("端口仍由本应用使用，无法启动服务。")
            }
            run.startRequested = false
            run.automaticStartRequested = false
            run.failureMessage = nil
            do {
                run.service.appendMonitorEvent("启动服务进程（第 \(run.retries + 1) 次尝试）。")
                let process = try PortProcess(service: run.service)
                run.process = process
                run.service.appendMonitorEvent("服务进程 PID \(process.pid) 已创建。")
                run.startedAt = Date()
                run.hasListened = false
                run.missingSince = nil
                run.stableSince = nil
                publish(run, .starting, "等待服务监听端口，最长 90 秒。")
            } catch { fail(run, error.localizedDescription) }
        } else {
            if run.placeholder == nil { run.placeholder = try PortPlaceholder(port: run.service.port, queue: queue) }
            publish(run, run.idleStatus.phase, run.idleStatus.detail)
        }
    }

    private func fail(_ run: Runtime, _ message: String) {
        if let process = run.process, let exitSummary = process.exitSummary {
            run.service.appendMonitorEvent("服务进程 PID \(process.pid) \(exitSummary)。")
        }
        beginStopping(run)
        run.startRequested = false
        run.automaticStartRequested = false
        run.failureMessage = message
        scheduleRecovery(run, message)
    }

    private func scheduleRecovery(_ run: Runtime, _ message: String) {
        if run.service.automaticallyRecover && run.retries < timing.retryLimit {
            let delay = min(30, timing.retryBase * pow(2, Double(run.retries)))
            run.retries += 1
            run.retryAt = Date().addingTimeInterval(TimeInterval(delay))
            publish(run, .retrying, "\(message) \(Int(delay)) 秒后重试（\(run.retries)/\(timing.retryLimit)）。")
        } else {
            run.retryAt = nil
            publish(run, .failed, message + (run.service.automaticallyRecover ? " 已达到 \(timing.retryLimit) 次重试上限。" : "请从菜单栏重试。"))
        }
        run.idleStatus = run.status
    }

    private func releasePlaceholder(_ run: Runtime) {
        guard let placeholder = run.placeholder else { return }
        run.placeholder = nil
        run.releasingPlaceholder = true
        placeholder.stop {
            run.releasingPlaceholder = false
        }
    }
}
