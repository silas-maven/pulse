import Foundation

enum QuotaConfig {
    static let providersFile: URL = Config.configDir.appendingPathComponent("providers.json")

    static func bootstrap() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: providersFile.path) {
            let defaults: [[String: Any]] = [
                [
                    "provider": "codex",
                    "displayName": "Codex (OpenAI)",
                    "source": "auto",
                    "enabled": true,
                ],
                [
                    "provider": "claude-code",
                    "displayName": "Claude Code",
                    "source": "cli",
                    "enabled": true,
                ],
                [
                    "provider": "openrouter",
                    "displayName": "OpenRouter",
                    "source": "api",
                    "apiKey": "",
                    "enabled": false,
                ],
            ]
            if let data = try? JSONSerialization.data(withJSONObject: defaults, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: providersFile)
            }
        }
    }

    static func loadProviders() -> [QuotaDefinition] {
        bootstrap()
        guard let data = try? Data(contentsOf: providersFile) else { return [] }
        return (try? JSONDecoder().decode([QuotaDefinition].self, from: data)) ?? []
    }
}
