import Foundation
import Observation

@Observable
@MainActor
final class QuotaManager {
    var quotas: [QuotaState] = []
    private var pollTimer: Timer?

    init() {
        loadConfig()
        startPolling()
        Task { await refreshAll() }
    }

    func loadConfig() {
        let defs = QuotaConfig.loadProviders()
        quotas = defs.filter(\.enabled).map { QuotaState(definition: $0) }
    }

    func refreshAll() async {
        for i in quotas.indices {
            quotas[i].status = .loading
        }
        // Fetch all in parallel
        await withTaskGroup(of: (String, QuotaStatus).self) { group in
            for quota in quotas {
                let def = quota.definition
                group.addTask {
                    let status = await Self.fetchQuota(for: def)
                    return (def.id, status)
                }
            }
            for await (id, status) in group {
                if let idx = quotas.firstIndex(where: { $0.id == id }) {
                    quotas[idx].status = status
                }
            }
        }
    }

    var hasWarning: Bool {
        quotas.contains { $0.status.isWarning || $0.status.isCritical }
    }

    private static func fetchQuota(for def: QuotaDefinition) async -> QuotaStatus {
        switch def.provider {
        case "openrouter":
            guard let key = def.apiKey, !key.isEmpty else {
                return .error("No API key")
            }
            return await OpenRouterFetcher.fetch(apiKey: key)

        case "claude-code":
            return await ClaudeCodeFetcher.fetch()

        case "codex":
            return await CodexFetcher.fetch()

        default:
            return .error("Unknown provider: \(def.provider)")
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }
}
