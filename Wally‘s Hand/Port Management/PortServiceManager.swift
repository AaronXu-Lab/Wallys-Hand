import Combine
import Foundation

@MainActor
final class PortServiceManager: ObservableObject {
    private struct Backup: Codable {
        let version: Int
        let services: [PortService]
    }

    enum BackupError: LocalizedError {
        case unsupportedVersion
        case duplicateConfiguration
        case protectedServices

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "不支持此版本的端口配置备份。"
            case .duplicateConfiguration: "备份中有重复的服务 ID 或端口。"
            case .protectedServices: "请先停用所有服务保护，再导入配置。"
            }
        }
    }

    static let shared = PortServiceManager()
    @Published private(set) var services: [PortService] = []
    @Published private(set) var statuses: [UUID: PortServiceStatus] = [:]
    @Published private(set) var storageError: String?
    private let defaults: UserDefaults
    private static let storageKey = "managedPortServices.v1"
    private lazy var supervisor = PortSupervisor { [weak self] id, status in
        DispatchQueue.main.async { self?.statuses[id] = status }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            do { services = try JSONDecoder().decode([PortService].self, from: data) }
            catch { storageError = "无法读取端口配置：\(error.localizedDescription)" }
        }
    }

    func status(_ id: UUID) -> PortServiceStatus { statuses[id] ?? PortServiceStatus() }
    var hasAttention: Bool { services.contains { status($0.id).needsAttention } }
    var hasProtection: Bool { services.contains { status($0.id).protected } }
    var problemServices: [PortService] {
        services.filter { status($0.id).protected && status($0.id).needsAttention }
    }
    func retryProblemServices() {
        for service in problemServices { retry(service.id) }
    }

    /// Includes every saved service and its recovery/logging options, but no running state.
    func exportBackup() throws -> Data {
        if let storageError { throw NSError(domain: "PortServiceManager", code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: storageError]) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Backup(version: 1, services: services))
    }

    /// Replaces the saved list. Imported services stay disabled until manually enabled.
    func importBackup(_ data: Data) throws {
        guard !hasProtection else { throw BackupError.protectedServices }
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        guard backup.version == 1 else { throw BackupError.unsupportedVersion }
        let ids = Set(backup.services.map(\.id))
        let ports = Set(backup.services.map(\.port))
        guard ids.count == backup.services.count, ports.count == backup.services.count,
              backup.services.allSatisfy({ (1...65535).contains($0.port) })
        else { throw BackupError.duplicateConfiguration }
        if let error = persist(backup.services) {
            throw NSError(domain: "PortServiceManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: error])
        }
        statuses.removeAll()
        storageError = nil
    }
    var tooltip: String {
        let enabled = services.filter { status($0.id).protected }
        guard !enabled.isEmpty else { return "Wally‘s Hand" }
        return enabled.map { "\($0.name) :\($0.port) — \(status($0.id).phase.rawValue)" }.joined(separator: "\n")
    }

    func save(_ service: PortService) -> String? {
        guard storageError == nil else { return storageError }
        guard !status(service.id).protected else { return "请先停用保护，再修改配置。" }
        if let error = service.validationError(existing: services) { return error }
        var updated = services
        if let index = updated.firstIndex(where: { $0.id == service.id }) { updated[index] = service }
        else { updated.append(service) }
        let error = persist(updated)
        if error == nil { statuses.removeValue(forKey: service.id) }
        return error
    }

    /// Recovery policy can change while protected; process configuration still requires disabling.
    func setAutomaticallyRecover(_ enabled: Bool, for id: UUID) -> String? {
        guard storageError == nil else { return storageError }
        guard let index = services.firstIndex(where: { $0.id == id }) else { return "找不到服务配置。" }
        guard services[index].automaticallyRecover != enabled else { return nil }
        var updated = services
        updated[index].automaticallyRecover = enabled
        if let error = persist(updated) { return error }
        supervisor.setAutomaticallyRecover(enabled, for: id)
        return nil
    }

    func setMonitorLogs(_ enabled: Bool, for id: UUID) -> String? {
        guard storageError == nil else { return storageError }
        guard let index = services.firstIndex(where: { $0.id == id }) else { return "找不到服务配置。" }
        guard services[index].isMonitoringLogs != enabled else { return nil }
        var updated = services
        updated[index].monitorLogs = enabled
        if let error = persist(updated) { return error }
        supervisor.setMonitorLogs(enabled, for: id)
        return nil
    }

    func remove(_ service: PortService) -> String? {
        guard !status(service.id).protected else { return "请先停用保护，再删除配置。" }
        let error = persist(services.filter { $0.id != service.id })
        if error == nil { statuses.removeValue(forKey: service.id) }
        return error
    }

    private func persist(_ updated: [PortService]) -> String? {
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: Self.storageKey)
            services = updated
            return nil
        } catch { return error.localizedDescription }
    }

    func enable(_ service: PortService) {
        guard !status(service.id).protected else { return }
        if let error = service.validationError(existing: services) {
            statuses[service.id] = PortServiceStatus(phase: .conflict, detail: error)
            return
        }
        statuses[service.id] = PortServiceStatus(phase: .starting, protected: true)
        supervisor.enable(service)
    }
    func retry(_ id: UUID) { supervisor.retry(id) }
    func stop(_ id: UUID) { supervisor.stop(id, disable: false) }
    func disable(_ id: UUID) { supervisor.stop(id, disable: true) }
    func shutdown(completion: @escaping () -> Void) {
        supervisor.shutdown { DispatchQueue.main.async { completion() } }
    }
}
