import Darwin
import Foundation

/// Minimal local HTTP responder. All descriptor operations run on the supervisor queue.
final class PortPlaceholder {
    private let queue: DispatchQueue
    private var sources: [DispatchSourceRead] = []
    private var clients: [Int32: DispatchSourceRead] = [:]
    private let closes = DispatchGroup()

    init(port: Int, queue: DispatchQueue) throws {
        self.queue = queue
        do {
            try listen(port: port, ipv6: false)
            try listen(port: port, ipv6: true)
        } catch {
            stop {}
            throw error
        }
    }

    private func listen(port: Int, ipv6: Bool) throws {
        let fd = socket(ipv6 ? AF_INET6 : AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw PortProcessError.message("无法创建占位服务。") }
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        let result: Int32
        if ipv6 {
            setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &one, socklen_t(MemoryLayout<Int32>.size))
            var address = sockaddr_in6()
            address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            address.sin6_family = sa_family_t(AF_INET6)
            address.sin6_port = UInt16(port).bigEndian
            address.sin6_addr = in6addr_loopback
            result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) }
            }
        } else {
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16(port).bigEndian
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        }
        guard result == 0, Darwin.listen(fd, 16) == 0 else {
            let message = String(cString: strerror(errno))
            close(fd)
            throw PortProcessError.message("占位服务无法监听端口：\(message)")
        }
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptClients(fd) }
        closes.enter()
        let group = closes
        source.setCancelHandler { close(fd); group.leave() }
        sources.append(source)
        source.resume()
    }

    private func acceptClients(_ fd: Int32) {
        // Bound each turn so incoming connections cannot starve stop/retry actions.
        for _ in 0..<16 {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            guard clients.count < 32 else { close(client); continue }
            _ = fcntl(client, F_SETFL, O_NONBLOCK)
            var one: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
            let source = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue)
            source.setEventHandler { [weak self] in self?.respond(client) }
            closes.enter()
            let group = closes
            source.setCancelHandler { close(client); group.leave() }
            clients[client] = source
            source.resume()
            queue.asyncAfter(deadline: .now() + 2) { [weak self, weak source] in
                guard let self, let source, self.clients[client] === source else { return }
                self.clients.removeValue(forKey: client)?.cancel()
            }
        }
    }

    private func respond(_ fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        _ = read(fd, &buffer, buffer.count)
        let body = """
        <!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <title>服务暂不可用</title><style>:root{color-scheme:light dark}body{font:16px system-ui;max-width:32rem;margin:20vh auto;padding:24px}p{opacity:.65;line-height:1.7}</style>
        <h1>服务暂不可用</h1><p>此端口由 Wally‘s Hand 保护。每 2 秒检查一次，恢复后自动刷新。</p><p>也可在菜单栏查看服务状态或重试。</p>
        <script>
        (() => {
            async function checkService() {
                const controller = new AbortController();
                const timeout = setTimeout(() => controller.abort(), 2000);
                let restored = false;
                try {
                    const response = await fetch(window.location.href, {
                        cache: 'no-store', redirect: 'manual', signal: controller.signal
                    });
                    restored = response.headers.get('X-WallysHand-Placeholder') !== '1' &&
                        (response.type === 'opaqueredirect' || (response.status >= 200 && response.status < 500));
                    if (response.body) response.body.cancel().catch(() => {});
                } catch (_) {
                    // Keep this page alive across refused connections and startup timeouts.
                } finally {
                    clearTimeout(timeout);
                }
                if (restored) window.location.reload();
                else setTimeout(checkService, 2000);
            }
            setTimeout(checkService, 2000);
        })();
        </script></html>
        """
        let response = "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nCache-Control: no-store\r\nX-WallysHand-Placeholder: 1\r\nConnection: close\r\n\r\n\(body)"
        response.utf8CString.withUnsafeBytes { bytes in
            _ = send(fd, bytes.baseAddress, bytes.count - 1, 0)
        }
        clients.removeValue(forKey: fd)?.cancel()
    }

    func stop(completion: @escaping () -> Void) {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        clients.values.forEach { $0.cancel() }
        clients.removeAll()
        closes.notify(queue: queue, execute: completion)
    }
}
