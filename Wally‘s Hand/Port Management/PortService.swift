import Darwin
import Foundation

struct PortService: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var port = 3000
    var directory = ""
    var command = ""
    var automaticallyRecover = false
    // Optional so configurations saved before this setting existed still decode.
    var monitorLogs: Bool? = nil

    var isMonitoringLogs: Bool { monitorLogs == true }

    func validationError(existing: [PortService]) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请输入服务名称。" }
        if !(1...65535).contains(port) { return "端口范围为 1–65535。" }
        if existing.contains(where: { $0.id != id && $0.port == port }) { return "该端口已配置。" }
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: expandedDirectory, isDirectory: &isDirectory) || !isDirectory.boolValue {
            return "请选择有效的项目目录。"
        }
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请输入启动命令。" }
        return nil
    }

    var expandedDirectory: String { (directory as NSString).expandingTildeInPath }
    var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/WallysHand/Ports/\(id.uuidString).log")
    }

    func appendMonitorEvent(_ message: String) {
        guard isMonitoringLogs else { return }
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(logURL.path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[Wally’s Hand \(timestamp)] \(message)\n"
        let bytes = Array(line.utf8)
        bytes.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = write(descriptor, base, buffer.count)
        }
    }
}

struct PortServiceStatus: Equatable {
    enum Phase: String {
        case disabled = "未启用"
        case starting = "启动中"
        case running = "运行中"
        case interrupted = "连接中断"
        case stopped = "已停止，端口保留"
        case failed = "运行异常"
        case retrying = "等待重试"
        case conflict = "端口冲突"
    }
    var menuEmoji: String {
        switch phase {
        case .disabled: "⚪️"
        case .starting: "🚀"
        case .running: "🟢"
        case .interrupted: "🟠"
        case .stopped: "⏸️"
        case .failed: "🔴"
        case .retrying: "🔄"
        case .conflict: "⚠️"
        }
    }

    var phase: Phase = .disabled
    var detail = ""
    var protected = false
    var needsAttention: Bool { [.interrupted, .failed, .conflict, .retrying].contains(phase) }
}
