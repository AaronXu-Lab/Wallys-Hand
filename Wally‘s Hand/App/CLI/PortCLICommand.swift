import Foundation

struct PortCLICommand: Codable {
    let action: String
    let target: String?
    let options: [String: String]

    static let help = """
    Usage: wally ports <list|add|edit|delete> [port-or-UUID] [options]
      list
      add PORT --name NAME --directory PATH --command COMMAND
      edit PORT-OR-UUID [--port PORT] [--name NAME] [--directory PATH] [--command COMMAND]
      delete PORT-OR-UUID
    Options for add/edit: --auto-recover true|false --monitor-logs true|false
    Added services remain disabled. Output is JSON; failures exit with code 1.
    """

    static func parse(_ arguments: [String]) throws -> Self {
        guard arguments.count >= 2, arguments[0] == "ports",
              ["list", "add", "edit", "delete"].contains(arguments[1]) else { throw CLIError(help) }
        let action = arguments[1]
        var index = 2
        var target: String?
        if action != "list" {
            guard arguments.count > index, !arguments[index].hasPrefix("--") else { throw CLIError("缺少端口或 UUID。") }
            target = arguments[index]
            index += 1
        }
        var options: [String: String] = [:]
        let allowed = ["--name", "--directory", "--command", "--port", "--auto-recover", "--monitor-logs"]
        while index < arguments.count {
            let key = arguments[index]
            guard ["add", "edit"].contains(action), allowed.contains(key), index + 1 < arguments.count,
                  options[key] == nil else { throw CLIError("未知、重复或缺少值的参数：\(key)") }
            options[key] = arguments[index + 1]
            index += 2
        }
        if action == "add" {
            guard options["--port"] == nil else { throw CLIError("新增端口请使用 add PORT。") }
            for key in ["--name", "--directory", "--command"] where options[key] == nil {
                throw CLIError("缺少参数：\(key)")
            }
        }
        if action == "edit", options.isEmpty { throw CLIError("请指定要修改的字段。") }
        if action == "add" || (target != nil && UUID(uuidString: target!) == nil) {
            guard let port = Int(target ?? ""), (1...65535).contains(port) else { throw CLIError("端口范围为 1–65535。") }
        }
        if let value = options["--port"], Int(value).map({ (1...65535).contains($0) }) != true {
            throw CLIError("端口范围为 1–65535。")
        }
        for key in ["--auto-recover", "--monitor-logs"] {
            if let value = options[key], !["true", "false"].contains(value) { throw CLIError("\(key) 必须为 true 或 false。") }
        }
        if let directory = options["--directory"] {
            let expanded = (directory as NSString).expandingTildeInPath
            options["--directory"] = URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)).standardizedFileURL.path
        }
        return Self(action: action, target: target, options: options)
    }
}

struct CLIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct PortCLIResponse: Codable {
    let success: Bool
    let message: String
    let services: [PortService]
}

@MainActor
extension PortServiceManager {
    func executeCLI(_ command: PortCLICommand) -> PortCLIResponse {
        do {
            if let storageError { throw CLIError(storageError) }
            if command.action == "list" { return PortCLIResponse(success: true, message: "", services: services) }
            var service: PortService
            if command.action == "add" {
                service = PortService()
                guard let port = Int(command.target ?? "") else { throw CLIError("无效端口。") }
                service.port = port
            } else {
                guard let found = services.first(where: { $0.id.uuidString.lowercased() == command.target?.lowercased() || String($0.port) == command.target }) else { throw CLIError("找不到服务配置。") }
                service = found
            }
            if command.action == "delete" {
                if let error = remove(service) { throw CLIError(error) }
            } else {
                guard ["add", "edit"].contains(command.action) else { throw CLIError("未知命令。") }
                if let value = command.options["--name"] { service.name = value }
                if let value = command.options["--directory"] { service.directory = value }
                if let value = command.options["--command"] { service.command = value }
                if let value = command.options["--port"], let port = Int(value) { service.port = port }
                if let value = command.options["--auto-recover"] { service.automaticallyRecover = value == "true" }
                if let value = command.options["--monitor-logs"] { service.monitorLogs = value == "true" }
                if let error = save(service) { throw CLIError(error) }
            }
            return PortCLIResponse(success: true, message: command.action, services: [service])
        } catch { return PortCLIResponse(success: false, message: error.localizedDescription, services: []) }
    }
}
