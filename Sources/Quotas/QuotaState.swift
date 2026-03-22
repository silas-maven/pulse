import Foundation

struct QuotaState: Identifiable, Sendable {
    let definition: QuotaDefinition
    var status: QuotaStatus = .unknown

    var id: String { definition.id }
    var displayName: String { definition.displayName }
}

enum QuotaStatus: Sendable {
    case loaded(QuotaData)
    case error(String)
    case loading
    case unknown

    var data: QuotaData? {
        if case .loaded(let d) = self { return d }
        return nil
    }

    var isWarning: Bool {
        guard let d = data else { return false }
        return d.tiers.contains { $0.percent > 80 }
    }

    var isCritical: Bool {
        guard let d = data else { return false }
        return d.tiers.contains { $0.percent > 95 }
    }
}

/// A single usage tier (e.g. "Session (5h)", "Weekly (7d)", "Context")
struct QuotaTier: Sendable {
    let name: String       // "Session (5h)", "Weekly (7d)", "Context"
    let percent: Double    // 0–100
    let resetsAt: Date?
    let detail: String?    // optional extra info like "45K/200K tokens"

    var resetsIn: String? {
        guard let resetsAt else { return nil }
        let diff = resetsAt.timeIntervalSince(Date())
        if diff <= 0 { return "now" }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        if h > 24 {
            let d = h / 24
            return "\(d)d \(h % 24)h"
        }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct QuotaData: Sendable {
    let tiers: [QuotaTier]
    let healthy: Bool
    let fetchedAt: Date

    /// Convenience for single-tier providers
    init(used: Double, limit: Double?, unit: String, resetsAt: Date?, source: String, healthy: Bool, fetchedAt: Date) {
        let pct: Double
        if let limit, limit > 0 {
            pct = min(used / limit * 100, 100)
        } else {
            pct = 0
        }
        let detail: String?
        if let limit {
            detail = "\(Self.fmt(used)) / \(Self.fmt(limit)) \(unit)"
        } else {
            detail = source
        }
        self.tiers = [QuotaTier(name: source, percent: pct, resetsAt: resetsAt, detail: detail)]
        self.healthy = healthy
        self.fetchedAt = fetchedAt
    }

    /// Multi-tier init
    init(tiers: [QuotaTier], healthy: Bool, fetchedAt: Date) {
        self.tiers = tiers
        self.healthy = healthy
        self.fetchedAt = fetchedAt
    }

    private static func fmt(_ n: Double) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", n / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", n / 1_000) }
        if n == floor(n) { return String(format: "%.0f", n) }
        return String(format: "%.2f", n)
    }
}
