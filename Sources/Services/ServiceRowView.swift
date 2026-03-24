import SwiftUI

struct ServiceRowView: View {
    let service: ServiceState
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                // Status dot
                statusDot

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

                // Status text for starting/failed
                if service.status.isStarting {
                    Text("starting…")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                if service.status.isFailed {
                    Text("FAILED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
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
                } else if service.status.isStarting {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
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

            // Error detail row
            if let msg = service.status.failureMessage {
                Text(msg)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.7))
                    .lineLimit(2)
                    .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusDot: some View {
        if service.status.isStarting {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .opacity(0.8)
        } else if service.status.isFailed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
        } else {
            Circle()
                .fill(service.status.isRunning ? Color.green : Color.red.opacity(0.6))
                .frame(width: 8, height: 8)
        }
    }
}
