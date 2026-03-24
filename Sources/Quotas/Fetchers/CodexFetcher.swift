import Foundation

enum CodexFetcher {
    /// Fetches Codex session data from `openclaw status --json`.
    static func fetch() async -> QuotaStatus {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Use full PATH so openclaw resolves when launched from .app bundle
        proc.arguments = ["-l", "-c", "export PATH=\"$HOME/.local/bin:$HOME/Library/pnpm:/opt/homebrew/bin:/usr/local/bin:$PATH\"; openclaw status --json 2>/dev/null"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return .error("CLI failed")
        }

        guard proc.terminationStatus == 0 else {
            return .error("CLI exit \(proc.terminationStatus)")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessions = json["sessions"] as? [String: Any],
              let recent = (sessions["recent"] as? [[String: Any]])?.first else {
            return .error("No session data")
        }

        let model = (recent["model"] as? String ?? "unknown")
            .replacingOccurrences(of: "gpt-", with: "")
        let percentUsed = recent["percentUsed"] as? Double ?? 0
        let contextTokens = recent["contextTokens"] as? Double ?? 0
        let remainingTokens = recent["remainingTokens"] as? Double ?? 0
        let usedTokens = contextTokens - remainingTokens

        let tiers = [
            QuotaTier(
                name: "Context",
                percent: percentUsed,
                resetsAt: nil,
                detail: "\(formatTokens(usedTokens)) / \(formatTokens(contextTokens)) · \(model)"
            ),
        ]

        return .loaded(QuotaData(tiers: tiers, healthy: percentUsed < 80, fetchedAt: Date()))
    }

    private static func formatTokens(_ n: Double) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", n / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", n / 1_000) }
        return String(format: "%.0f", n)
    }
}
