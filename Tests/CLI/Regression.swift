import Foundation

@main
struct CLIRegression {
    @MainActor
    static func main() async throws {
        let suite = "WallyCLITests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = PortServiceManager(defaults: defaults)
        func run(_ arguments: [String]) throws -> PortCLIResponse {
            manager.executeCLI(try PortCLICommand.parse(["ports"] + arguments))
        }
        let added = try run(["add", "7680", "--name", "CLI fixture", "--directory", NSTemporaryDirectory(), "--command", "sleep 60"])
        precondition(added.success && manager.services.count == 1)
        let id = added.services[0].id
        precondition(!manager.status(id).protected)
        precondition(tryResult { try run(["add", "7680", "--name", "duplicate", "--directory", "/tmp", "--command", "true"]).success } == false)
        let edited = try run(["edit", "7680", "--port", "7681", "--name", "renamed", "--monitor-logs", "true"])
        precondition(edited.success && edited.services[0].id == id && edited.services[0].isMonitoringLogs)
        precondition(PortServiceManager(defaults: defaults).services == manager.services)
        precondition(tryResult { try run(["edit", "7681", "--directory", "/does-not-exist"]).success } == false)
        precondition(manager.services[0].directory != "/does-not-exist")
        precondition(tryResult { try run(["delete", "12345"]).success } == false)
        precondition(tryResult { try run(["list"]).services.count == 1 })
        precondition(tryResult { try run(["delete", id.uuidString]).success })
        precondition(manager.services.isEmpty)
        for arguments in [["add", "0"], ["edit", "7680"], ["list", "--name", "x"], ["delete", "bad"], ["edit", "7680", "--monitor-logs", "yes"], ["edit", "7680", "--name", "a", "--name", "b"]] {
            do { _ = try PortCLICommand.parse(["ports"] + arguments); fatalError("Accepted invalid arguments") }
            catch is CLIError { }
        }
        let protected = try run(["add", "49151", "--name", "guard fixture", "--directory", "/tmp", "--command", "/usr/bin/true"])
        manager.enable(protected.services[0])
        precondition(tryResult { try run(["edit", "49151", "--name", "blocked"]).success } == false)
        precondition(tryResult { try run(["delete", "49151"]).success } == false)
        await withCheckedContinuation { continuation in manager.shutdown { continuation.resume() } }
        print("CLI parser, CRUD, validation, stable IDs, persistence and protection guards passed")
    }
    static func tryResult(_ block: () throws -> Bool) -> Bool { (try? block()) ?? false }
}
