import SwiftUI

struct QuotaRowView: View {
    let quota: QuotaState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Provider header
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)

                Text(quota.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()

                // Status badge
                switch quota.status {
                case .loading:
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                case .error(let msg):
                    Text(msg)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.7))
                        .lineLimit(1)
                case .loaded(let data):
                    if !data.healthy {
                        Text("LOW")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                    } else {
                        Text("OK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                case .unknown:
                    Text("—")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Tier rows
            if case .loaded(let data) = quota.status {
                ForEach(Array(data.tiers.enumerated()), id: \.offset) { _, tier in
                    tierRow(tier)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func tierRow(_ tier: QuotaTier) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                // Tier label
                Text(tier.name)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(tier.percent))
                            .frame(width: geo.size.width * min(tier.percent / 100, 1))
                    }
                }
                .frame(height: 6)

                // Percentage
                Text("\(Int(tier.percent))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(percentColor(tier.percent))
                    .frame(width: 32, alignment: .trailing)

                // Reset timer
                if let reset = tier.resetsIn {
                    Text("↻ \(reset)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Detail line (token counts, model, etc.)
            if let detail = tier.detail {
                Text(detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 88)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 2)
    }

    private var dotColor: Color {
        switch quota.status {
        case .loaded(let d):
            if !d.healthy { return .red }
            if d.tiers.contains(where: { $0.percent > 95 }) { return .red }
            if d.tiers.contains(where: { $0.percent > 80 }) { return .orange }
            return .green
        case .error:
            return .red
        case .loading:
            return .yellow
        case .unknown:
            return Color.gray.opacity(0.5)
        }
    }

    private func barColor(_ pct: Double) -> Color {
        if pct > 95 { return .red }
        if pct > 80 { return .orange }
        return .green
    }

    private func percentColor(_ pct: Double) -> Color {
        if pct > 95 { return .red }
        if pct > 80 { return .orange }
        return .primary
    }
}
