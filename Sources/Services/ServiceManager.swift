import Foundation
import Observation

enum ServiceStatus: Sendable {
    case running(pid: Int)
    case stopped
    case starting
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isStarting: Bool {
        if case .starting = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }

    var pid: Int? {
        if case .running(let pid) = self { return pid }
        return nil
    }
}

struct ServiceState: Identifiable, Sendable {
    let definition: ServiceDefinition
    var status: ServiceStatus = .stopped

    var id: String { definition.id }
    var name: String { definition.name }
    var port: Int? { definition.port }
}

@Observable
@MainActor
final class ServiceManager {
    var services: [ServiceState] = []
    private var pollTimer: Timer?

    init() {
        Config.bootstrap()
        reload()
        startPolling()
    }

    // Timer cleanup handled by app lifecycle

    func reload() {
        let defs = Config.loadServices()
        services = defs.map { ServiceState(definition: $0) }
        refreshAll()
    }

    func refreshAll() {
        // Build a port→pid map with a single lsof call instead of one per service
        let portMap = ProcessUtil.allListeningPorts()
        for i in services.indices {
            services[i].status = checkStatus(services[i].definition, portMap: portMap)
        }
    }

    func start(_ service: ServiceState) {
        let def = service.definition
        let logPath = def.logFile ?? "/tmp/pulse-\(def.name.lowercased().replacingOccurrences(of: " ", with: "-")).log"

        // If already running, skip
        if let pName = def.portlessName, ProcessUtil.pidOfPortlessApp(name: pName) != nil {
            refreshAll()
            return
        }
        if let port = def.port, ProcessUtil.pidListeningOn(port: port) != nil {
            refreshAll()
            return
        }

        // Show starting state
        if let idx = services.firstIndex(where: { $0.id == service.id }) {
            services[idx].status = .starting
        }

        let cmd: String
        if let pName = def.portlessName {
            // Wrap in bash -c so && chains stay intact inside portless
            let escaped = def.command.replacingOccurrences(of: "'", with: "'\\''")
            cmd = "portless \(pName) bash -c '\(escaped)'"
        } else {
            cmd = def.command
        }
        ProcessUtil.spawn(command: cmd, logFile: logPath)

        // Check after 5s if it actually started
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            self.refreshAll()
            // If still not running after refresh, mark as failed
            if let idx = self.services.firstIndex(where: { $0.id == service.id }),
               !self.services[idx].status.isRunning {
                // Read last few lines of log for error info
                let msg = Self.lastLogLines(logPath, lines: 3)
                self.services[idx].status = .failed(msg ?? "Failed to start")
            }
        }
    }

    private static func lastLogLines(_ path: String?, lines: Int = 3) -> String? {
        guard let path else { return nil }
        let expanded = NSString(string: path).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expanded, encoding: .utf8) else { return nil }
        let allLines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let tail = allLines.suffix(lines)
        let result = tail.joined(separator: " | ")
        return result.isEmpty ? nil : String(result.prefix(120))
    }

    func stop(_ service: ServiceState) {
        // For Portless services, kill the portless wrapper process tree
        if let pName = service.definition.portlessName,
           let portlessPid = ProcessUtil.pidOfPortlessApp(name: pName) {
            ProcessUtil.terminateTree(pid: portlessPid)
        } else if let pid = service.status.pid {
            ProcessUtil.terminate(pid: pid)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.refreshAll()
        }
    }

    func restart(_ service: ServiceState) {
        if service.status.isRunning {
            stop(service)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self else { return }
                if let current = self.services.first(where: { $0.id == service.id }) {
                    self.start(current)
                }
            }
        } else {
            start(service)
        }
    }

    func restartAll() {
        for service in services where service.status.isRunning {
            stop(service)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            for service in self.services where self.services.first(where: { $0.id == service.id })?.definition.autostart == true {
                self.start(service)
            }
        }
    }

    /// Clears OpenClaw agent sessions and restarts the gateway.
    /// Forces a fresh context so skill file changes take effect immediately.
    func resetSession() {
        // 1. Clear session files for all agents
        let stateDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/agents")
        if let agents = try? FileManager.default.contentsOfDirectory(atPath: stateDir.path) {
            for agent in agents {
                let sessionsDir = stateDir.appendingPathComponent(agent).appendingPathComponent("sessions")
                let sessionsIndex = sessionsDir.appendingPathComponent("sessions.json")
                // Reset sessions index to empty array — keeps the dir, just clears sessions
                if FileManager.default.fileExists(atPath: sessionsIndex.path) {
                    try? "[]".write(to: sessionsIndex, atomically: true, encoding: .utf8)
                }
            }
        }

        // 2. Restart the gateway service
        if let gw = services.first(where: { $0.name.lowercased().contains("openclaw") || $0.name.lowercased().contains("gateway") }) {
            restart(gw)
        }
    }

    // MARK: - Private

    private func checkStatus(_ def: ServiceDefinition, portMap: [Int: Int] = [:]) -> ServiceStatus {
        // Portless-based check — find the portless wrapper process
        if let pName = def.portlessName,
           let pid = ProcessUtil.pidOfPortlessApp(name: pName) {
            return .running(pid: pid)
        }

        // Port-based check — use pre-built map if available
        if let port = def.port {
            if let pid = portMap[port] {
                return .running(pid: pid)
            } else if portMap.isEmpty, let pid = ProcessUtil.pidListeningOn(port: port) {
                return .running(pid: pid)
            }
        }

        // PID file check
        if let pidFile = def.pidFile, let pid = ProcessUtil.readPidFile(pidFile), ProcessUtil.isAlive(pid: pid) {
            return .running(pid: pid)
        }

        return .stopped
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
    }
}
