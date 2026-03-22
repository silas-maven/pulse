import Foundation

enum OpenRouterFetcher {
    /// GET https://openrouter.ai/api/v1/auth/key
    /// Returns: { data: { usage: float, limit: float|null, rate_limit: {...} } }
    static func fetch(apiKey: String) async -> QuotaStatus {
        guard let url = URL(string: "https://openrouter.ai/api/v1/auth/key") else {
            return .error("Bad URL")
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return .error("HTTP \(code)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let d = json["data"] as? [String: Any] else {
                return .error("Bad response")
            }

            let usage = d["usage"] as? Double ?? 0
            let limit = d["limit"] as? Double

            return .loaded(QuotaData(
                used: usage,
                limit: limit,
                unit: "credits",
                resetsAt: nil,  // OpenRouter doesn't have a fixed reset
                source: "api",
                healthy: true,
                fetchedAt: Date()
            ))
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
