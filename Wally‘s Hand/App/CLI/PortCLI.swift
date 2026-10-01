import AppKit

/// Local, same-login-session IPC. Only the app owns configuration and supervision state.
enum PortCLI {
    static let requestName = Notification.Name("com.xuweinan.LoopJust.cli.request.v1")
    static let replyName = Notification.Name("com.xuweinan.LoopJust.cli.reply.v1")
    static let bundleID = "com.xuweinan.LoopJust"

    @MainActor
    static func run(_ arguments: [String]) -> Int32 {
        if arguments.isEmpty || arguments == ["--help"] || arguments == ["ports", "--help"] {
            print(PortCLICommand.help)
            return 0
        }
        do {
            let command = try PortCLICommand.parse(arguments)
            let ownPID = ProcessInfo.processInfo.processIdentifier
            func running() -> [NSRunningApplication] {
                NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { $0.processIdentifier != ownPID }
            }
            if running().isEmpty {
                let opener = Process()
                opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                opener.arguments = ["-g", Bundle.main.bundleURL.path, "--args", "--cli-background"]
                try opener.run()
                opener.waitUntilExit()
                guard opener.terminationStatus == 0 else { throw CLIError("无法启动应用。") }
            }
            let deadline = Date().addingTimeInterval(10)
            var host: NSRunningApplication?
            while Date() < deadline {
                let candidates = running()
                guard candidates.count <= 1 else { throw CLIError("检测到多个应用实例，请关闭多余实例后重试。") }
                if let candidate = candidates.first,
                   request("ping", pid: candidate.processIdentifier, timeout: 0.3) != nil {
                    host = candidate
                    break
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            guard let host else { throw CLIError("应用未响应 CLI，请重新启动最新构建的应用后重试。") }
            let data = try JSONEncoder().encode(command)
            let payload = data.base64EncodedString()
            guard payload.utf8.count < 65536 else { throw CLIError("命令参数过长。") }
            guard let response = request(payload, pid: host.processIdentifier, timeout: 10) else {
                throw CLIError("请求超时，结果未知。请先运行 ports list 核对配置，避免重复操作。")
            }
            guard let responseData = Data(base64Encoded: response) else { throw CLIError("无效的 CLI 响应。") }
            let result = try JSONDecoder().decode(PortCLIResponse.self, from: responseData)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            print(String(decoding: try encoder.encode(result), as: UTF8.self))
            return result.success ? 0 : 1
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            return 1
        }
    }

    private static func request(_ payload: String, pid: pid_t, timeout: TimeInterval) -> String? {
        let center = DistributedNotificationCenter.default()
        let id = UUID().uuidString
        var reply: String?
        let observer = center.addObserver(forName: replyName, object: id, queue: .main) { notification in
            reply = notification.userInfo?["payload"] as? String
        }
        defer { center.removeObserver(observer) }
        center.postNotificationName(requestName, object: String(pid), userInfo: ["id": id, "payload": payload], deliverImmediately: true)
        let deadline = Date().addingTimeInterval(timeout)
        while reply == nil, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        return reply
    }
}

@MainActor
final class PortCLIServer {
    private var observer: Any?

    init() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: PortCLI.requestName, object: String(ProcessInfo.processInfo.processIdentifier), queue: .main
        ) { notification in
            guard let id = notification.userInfo?["id"] as? String, UUID(uuidString: id) != nil,
                  let payload = notification.userInfo?["payload"] as? String, payload.utf8.count < 65536 else { return }
            Task { @MainActor in
                let reply: String
                if payload == "ping" { reply = "pong" }
                else {
                    guard let data = Data(base64Encoded: payload),
                          let command = try? JSONDecoder().decode(PortCLICommand.self, from: data) else { return }
                    let response = PortServiceManager.shared.executeCLI(command)
                    guard let encoded = try? JSONEncoder().encode(response) else { return }
                    reply = encoded.base64EncodedString()
                }
                DistributedNotificationCenter.default().postNotificationName(
                    PortCLI.replyName, object: id, userInfo: ["payload": reply], deliverImmediately: true
                )
            }
        }
    }

    deinit {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
    }
}
