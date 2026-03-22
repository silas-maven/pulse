import Foundation

enum Config {
    static let configDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".pulse")
    }()

    static let servicesFile: URL = configDir.appendingPathComponent("services.json")

    /// Ensure config directory exists and seed a default services.json if missing.
    static func bootstrap() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir.path) {
            try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: servicesFile.path) {
            // Seed an empty array so the user can add their own services.
            // See README.md for the services.json format.
            let defaultServices: [[String: Any]] = []
            if let data = try? JSONSerialization.data(withJSONObject: defaultServices, options: [.prettyPrinted]) {
                try? data.write(to: servicesFile)
            }
        }
    }

    static func loadServices() -> [ServiceDefinition] {
        guard let data = try? Data(contentsOf: servicesFile) else { return [] }
        return (try? JSONDecoder().decode([ServiceDefinition].self, from: data)) ?? []
    }
}
