import Foundation

struct QuotaDefinition: Codable, Identifiable, Sendable {
    var id: String { provider }
    let provider: String
    let displayName: String
    let source: QuotaSource
    let apiKey: String?
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case provider, displayName, source, apiKey, enabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decode(String.self, forKey: .provider)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? provider
        source = try c.decodeIfPresent(QuotaSource.self, forKey: .source) ?? .auto
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

enum QuotaSource: String, Codable, Sendable {
    case api
    case cli
    case local
    case auto
}
