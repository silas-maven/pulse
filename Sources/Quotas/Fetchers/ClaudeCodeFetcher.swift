import Foundation

enum ClaudeCodeFetcher {
    /// Fetches Claude usage from the internal OAuth usage endpoint.
    static func fetch() async -> QuotaStatus {
        guard let token = getOAuthToken() else {
            return .error("No OAuth token")
        }

        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            return .error("Bad URL")
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return .error("HTTP \(code)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .error("Bad JSON")
            }

            return .loaded(buildQuotaData(json))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private static func getOAuthToken() -> String? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }

        guard proc.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let json = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }

        return token
    }

    private static func buildQuotaData(_ json: [String: Any]) -> QuotaData {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fiveHour = json["five_hour"] as? [String: Any]
        let sevenDay = json["seven_day"] as? [String: Any]

        let sessionPct = fiveHour?["utilization"] as? Double ?? 0
        let sessionReset: Date? = {
            guard let s = fiveHour?["resets_at"] as? String else { return nil }
            return iso.date(from: s)
        }()

        let weeklyPct = sevenDay?["utilization"] as? Double ?? 0
        let weeklyReset: Date? = {
            guard let s = sevenDay?["resets_at"] as? String else { return nil }
            return iso.date(from: s)
        }()

        let tiers = [
            QuotaTier(
                name: "Session (5h)",
                percent: sessionPct,
                resetsAt: sessionReset,
                detail: nil
            ),
            QuotaTier(
                name: "Weekly (7d)",
                percent: weeklyPct,
                resetsAt: weeklyReset,
                detail: nil
            ),
        ]

        let maxPct = max(sessionPct, weeklyPct)
        return QuotaData(tiers: tiers, healthy: maxPct < 90, fetchedAt: Date())
    }
}
