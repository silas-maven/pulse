import SwiftUI

struct ServiceRowView: View {
    let service: ServiceState
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(service.status.isRunning ? Color.green : Color.red.opacity(0.6))
                .frame(width: 8, height: 8)

            // Name
            Text(service.name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(service.status.isRunning ? .primary : .secondary)

            Spacer()

            // Port label
            if let port = service.port {
                Text(":\(port)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // PID label (when running)
            if let pid = service.status.pid {
                Text("pid \(pid)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Controls
            if service.status.isRunning {
                Button(action: onRestart) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Restart")

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Stop")
            } else {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.borderless)
                .help("Start")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
