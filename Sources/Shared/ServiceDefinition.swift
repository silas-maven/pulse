import Foundation

struct ServiceDefinition: Codable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let command: String
    let port: Int?
    let pidFile: String?
    let logFile: String?
    let autostart: Bool
    let portlessName: String?

    enum CodingKeys: String, CodingKey {
        case name, command, port, pidFile, logFile, autostart, portlessName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        command = try c.decode(String.self, forKey: .command)
        port = try c.decodeIfPresent(Int.self, forKey: .port)
        pidFile = try c.decodeIfPresent(String.self, forKey: .pidFile)
        logFile = try c.decodeIfPresent(String.self, forKey: .logFile)
        autostart = try c.decodeIfPresent(Bool.self, forKey: .autostart) ?? false
        portlessName = try c.decodeIfPresent(String.self, forKey: .portlessName)
    }

    init(name: String, command: String, port: Int?, pidFile: String? = nil, logFile: String? = nil, autostart: Bool = false, portlessName: String? = nil) {
        self.name = name
        self.command = command
        self.port = port
        self.pidFile = pidFile
        self.logFile = logFile
        self.autostart = autostart
        self.portlessName = portlessName
    }
}
