import Foundation
import Observation

enum ServiceStatus: Sendable {
    case running(pid: Int)
    case stopped

    var isRunning: Bool {
        if case .running = self { return true }
        return false
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
        for i in services.indices {
            services[i].status = checkStatus(services[i].definition)
        }
    }

    func start(_ service: ServiceState) {
        let def = service.definition
        let logPath = def.logFile ?? "/tmp/pulse-\(def.name.lowercased().replacingOccurrences(of: " ", with: "-")).log"

        // If already running on the port, skip
        if let port = def.port, ProcessUtil.pidListeningOn(port: port) != nil {
            refreshAll()
            return
        }

        let cmd: String
        if let pName = def.portlessName {
            cmd = "portless \(pName) \(def.command)"
        } else {
            cmd = def.command
        }
        ProcessUtil.spawn(command: cmd, logFile: logPath)

        // Give it a moment to start, then refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.refreshAll()
        }
    }

    func stop(_ service: ServiceState) {
        guard let pid = service.status.pid else { return }
        ProcessUtil.terminate(pid: pid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
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

    // MARK: - Private

    private func checkStatus(_ def: ServiceDefinition) -> ServiceStatus {
        // Port-based check
        if let port = def.port, let pid = ProcessUtil.pidListeningOn(port: port) {
            return .running(pid: pid)
        }

        // PID file check
        if let pidFile = def.pidFile, let pid = ProcessUtil.readPidFile(pidFile), ProcessUtil.isAlive(pid: pid) {
            return .running(pid: pid)
        }

        return .stopped
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
    }
}
