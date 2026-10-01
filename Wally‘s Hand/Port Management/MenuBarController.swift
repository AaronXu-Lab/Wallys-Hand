import AppKit
import Combine
import Defaults

/// AppKit owns only the status item; service state stays in PortServiceManager.
/// A native status button gives us a real tooltip, including while the menu is closed.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, NSMenuItemValidation {
    private let ports = PortServiceManager.shared
    private var statusItem: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()
    private var actions: [UUID: () -> Void] = [:]
    private let servicesAnchorTag = 567900
    private let retryProblemsTag = 567901
    private var serviceEntries: [UUID: ServiceEntry] = [:]

    private struct ServiceEntry {
        let service: PortService
        let item: NSMenuItem
        let status: NSMenuItem
        let detail: NSMenuItem
        let recovery: NSMenuItem
        let enable: NSMenuItem
        let retry: NSMenuItem
        let stop: NSMenuItem
        let disable: NSMenuItem
        let log: NSMenuItem
    }

    override init() {
        super.init()
        ports.objectWillChange.sink { [weak self] in
            RunLoop.main.perform(inModes: [.common]) { self?.refresh() }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &subscriptions)
        refresh()
    }

    private func refresh() {
        let visible = !Defaults[.hideMenuBarIcon] || ports.hasProtection
        guard visible else {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        }
        let image = ports.hasAttention
            ? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "服务异常")
            : NSImage(named: "menubarIcon")
        image?.isTemplate = true
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = ports.tooltip
        statusItem?.button?.setAccessibilityLabel(ports.tooltip)
        if let menu = statusItem?.menu, menu.indexOfItem(withTag: servicesAnchorTag) >= 0 {
            updateServices(in: menu)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        actions.removeAll()
        serviceEntries.removeAll()
        menu.removeAllItems()
        menu.addItem(withTitle: "Version \(VersionDisplay.current.fullDisplay)", action: nil, keyEquivalent: "")
        add(Updater.shared.updateState == .available ? "Update…" : "Check for Updates…", to: menu) {
            Task {
                await Updater.shared.fetchLatestInfo()
                await Updater.shared.showUpdateWindowIfEligible()
            }
        }
        add(String(localized: "打开 Wally‘s Hand"), to: menu) { WorkspaceWindowManager.shared.show() }
        add(String(localized: "窗口管理…"), to: menu) { WorkspaceWindowManager.shared.show(.windows) }
        add(String(localized: "Settings…"), key: ",", to: menu) { WorkspaceWindowManager.shared.show(.settings) }
        menu.addItem(.separator())
        let settings = add("端口管理…", to: menu) {
            WorkspaceWindowManager.shared.show(.ports)
        }
        settings.tag = servicesAnchorTag
        let retryProblems = add("重启异常服务", to: menu) { [weak self] in
            self?.ports.retryProblemServices()
        }
        retryProblems.tag = retryProblemsTag
        retryProblems.toolTip = "重启所有已启用保护且异常断开、启动失败、端口冲突或等待重试的服务。"
        updateServices(in: menu)
        menu.addItem(.separator())
        add(String(localized: "Quit \(Bundle.main.appName)"), key: "q", to: menu) { NSApp.terminate(nil) }
    }

    /// Stable partition: protected services first; preserve configured order within each group.
    /// Reuse menu items while tracking so status changes do not dismiss the open submenu.
    private func updateServices(in menu: NSMenu) {
        let problemCount = ports.problemServices.count
        if let retryProblems = menu.item(withTag: retryProblemsTag) {
            retryProblems.title = problemCount > 0 ? "重启异常服务（\(problemCount)）" : "重启异常服务"
            retryProblems.isEnabled = problemCount > 0
        }
        let services = ports.services.filter { ports.status($0.id).protected }
            + ports.services.filter { !ports.status($0.id).protected }
        for (id, entry) in Array(serviceEntries) where !services.contains(entry.service) {
            for child in entry.item.submenu?.items ?? [] {
                if let actionID = child.representedObject as? UUID { actions.removeValue(forKey: actionID) }
            }
            menu.removeItem(entry.item)
            serviceEntries.removeValue(forKey: id)
        }
        let anchor = menu.indexOfItem(withTag: servicesAnchorTag)
        let firstServiceIndex = anchor - serviceEntries.count
        for (offset, service) in services.enumerated() {
            let status = ports.status(service.id)
            let entry: ServiceEntry
            if let existing = serviceEntries[service.id] {
                entry = existing
            } else {
                entry = makeServiceEntry(service)
                serviceEntries[service.id] = entry
            }
            let name = service.name.count > 20 ? String(service.name.prefix(19)) + "…" : service.name
            entry.item.title = "\(status.menuEmoji) \(name) :\(service.port)"
            entry.item.toolTip = "\(service.name) :\(service.port) — \(status.phase.rawValue)"
            entry.item.setAccessibilityLabel(entry.item.toolTip)
            entry.status.title = status.phase.rawValue
            entry.detail.title = String(status.detail.prefix(60))
            entry.detail.toolTip = status.detail
            entry.detail.isHidden = status.detail.isEmpty
            entry.recovery.state = service.automaticallyRecover ? .on : .off
            entry.enable.isHidden = status.protected
            entry.retry.isHidden = !status.protected
            entry.stop.isHidden = !status.protected
            entry.disable.isHidden = !status.protected
            entry.log.isHidden = !FileManager.default.fileExists(atPath: service.logURL.path)
            let targetIndex = firstServiceIndex + offset
            let currentIndex = menu.index(of: entry.item)
            if currentIndex != targetIndex {
                if currentIndex >= 0 { menu.removeItem(entry.item) }
                menu.insertItem(entry.item, at: targetIndex)
            }
        }
    }

    private func makeServiceEntry(_ service: PortService) -> ServiceEntry {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let status = submenu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        let detail = submenu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        submenu.addItem(.separator())
        let recovery = add("异常后自动重启", to: submenu) { [weak self] in
            guard let self, let current = self.ports.services.first(where: { $0.id == service.id }) else { return }
            if let error = self.ports.setAutomaticallyRecover(!current.automaticallyRecover, for: service.id) {
                let alert = NSAlert()
                alert.messageText = "自动重启设置保存失败"
                alert.informativeText = error
                alert.runModal()
            }
        }
        recovery.toolTip = "服务异常后自动尝试重启，最多 10 次；手动停止后不会自动重启。"
        submenu.addItem(.separator())
        let enable = add("启动并保护端口", to: submenu) { [weak self] in self?.ports.enable(service) }
        let retry = add("启动 / 重试", to: submenu) { [weak self] in self?.ports.retry(service.id) }
        let stop = add("停止服务，保留端口", to: submenu) { [weak self] in self?.ports.stop(service.id) }
        let disable = add("停用保护并释放端口", to: submenu) { [weak self] in self?.ports.disable(service.id) }
        let log = add("查看日志", to: submenu) { NSWorkspace.shared.open(service.logURL) }
        item.submenu = submenu
        return ServiceEntry(service: service, item: item, status: status, detail: detail,
                            recovery: recovery, enable: enable, retry: retry, stop: stop, disable: disable, log: log)
    }

    @discardableResult
    private func add(_ title: String, key: String = "", to menu: NSMenu, action: @escaping () -> Void) -> NSMenuItem {
        let id = UUID()
        actions[id] = action
        let item = NSMenuItem(title: title, action: #selector(performAction(_:)), keyEquivalent: key)
        item.target = self
        item.representedObject = id
        menu.addItem(item)
        return item
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        actions[id]?()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.tag != retryProblemsTag || !ports.problemServices.isEmpty
    }
}
