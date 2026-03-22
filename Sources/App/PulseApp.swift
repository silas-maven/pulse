import SwiftUI

@main
struct PulseApp: App {
    @State private var serviceManager = ServiceManager()
    @State private var quotaManager = QuotaManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(serviceManager)
                .environment(quotaManager)
        } label: {
            MenuBarLabel(serviceManager: serviceManager, quotaManager: quotaManager)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar icon + status indicator.
struct MenuBarLabel: View {
    let serviceManager: ServiceManager
    let quotaManager: QuotaManager

    var body: some View {
        let running = serviceManager.services.filter(\.status.isRunning).count
        let total = serviceManager.services.count
        let allGood = running == total && total > 0
        let quotaWarning = quotaManager.hasWarning

        HStack(spacing: 4) {
            Image(systemName: "waveform.path.ecg")
            if total > 0 {
                Text("\(running)/\(total)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            Circle()
                .fill(quotaWarning ? Color.orange : (allGood ? Color.green : (running > 0 ? Color.orange : Color.red)))
                .frame(width: 6, height: 6)
        }
    }
}
