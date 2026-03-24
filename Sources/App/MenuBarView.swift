import SwiftUI

enum PulseTab: String, CaseIterable {
    case services = "Services"
    case quotas = "Quotas"
}

struct MenuBarView: View {
    @Environment(ServiceManager.self) private var serviceManager
    @Environment(QuotaManager.self) private var quotaManager
    @State private var activeTab: PulseTab = .services

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("PULSE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Spacer()
                statusSummary
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Tab switcher
            HStack(spacing: 0) {
                ForEach(PulseTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeTab = tab
                        }
                    } label: {
                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(activeTab == tab ? .primary : .tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(activeTab == tab ? Color.white.opacity(0.06) : Color.clear)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 8)

            // Content
            switch activeTab {
            case .services:
                servicesView
            case .quotas:
                quotasView
            }

            Divider()
                .padding(.horizontal, 8)

            // Footer
            HStack {
                Button("Reset Session") {
                    serviceManager.resetSession()
                }
                .font(.system(size: 10, design: .monospaced))
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
                .help("Clears OpenClaw sessions and restarts the gateway")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10, design: .monospaced))
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
    }

    // MARK: - Services Tab

    private var servicesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(serviceManager.services) { service in
                ServiceRowView(
                    service: service,
                    onStart: { serviceManager.start(service) },
                    onStop: { serviceManager.stop(service) },
                    onRestart: { serviceManager.restart(service) }
                )
            }

            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button("Restart All") {
                    serviceManager.restartAll()
                }
                .font(.system(size: 10, design: .monospaced))
                .buttonStyle(.borderless)

                Spacer()

                Button("Reload Config") {
                    serviceManager.reload()
                }
                .font(.system(size: 10, design: .monospaced))
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Quotas Tab

    private var quotasView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(quotaManager.quotas) { quota in
                QuotaRowView(quota: quota)
            }

            if quotaManager.quotas.isEmpty {
                Text("No providers configured")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button("Refresh") {
                    Task { await quotaManager.refreshAll() }
                }
                .font(.system(size: 10, design: .monospaced))
                .buttonStyle(.borderless)

                Spacer()

                Button("Reload Config") {
                    quotaManager.loadConfig()
                    Task { await quotaManager.refreshAll() }
                }
                .font(.system(size: 10, design: .monospaced))
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Status Summary

    @ViewBuilder
    private var statusSummary: some View {
        switch activeTab {
        case .services:
            let running = serviceManager.services.filter(\.status.isRunning).count
            let total = serviceManager.services.count
            Text("\(running)/\(total)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(running == total ? .green : .orange)
        case .quotas:
            if quotaManager.hasWarning {
                Text("LOW")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
            } else {
                Text("OK")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
    }
}
