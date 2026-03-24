# Pulse

A lightweight macOS menu bar app for managing local dev services and tracking AI coding tool quotas.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## What it does

Pulse sits in your menu bar and gives you two things at a glance:

**Services** — Start, stop, and restart local dev processes (API servers, build tools, background workers). Pulse monitors them by port or PID and shows live status. If a service fails to start, you'll see a `FAILED` indicator with the error from the log.

**Quotas** — See how much of your AI coding tool quota you've used. Supports Claude Code (session + weekly limits), Codex/OpenAI, and OpenRouter. Shows usage bars, percentages, and reset countdowns.

## Install

### As an app (recommended)

```bash
git clone https://github.com/silas-maven/pulse.git
cd pulse
swift build -c release
./scripts/install-app.sh
```

This builds Pulse in release mode and installs it to `~/Applications/Pulse.app`. You can then launch it from Spotlight or Launchpad. Pulse runs as a menu bar app with no Dock icon.

### Manual build

```bash
swift build -c release
.build/release/Pulse
```

Pulse will create `~/.pulse/` with empty defaults on first launch.

Requires **macOS 14+** and **Swift 6** (Xcode or Command Line Tools).

## Configuration

Pulse reads config from `~/.pulse/`. Edit the files directly, then hit **Reload Config** in the menu bar.

### Services (`~/.pulse/services.json`)

Define the processes you want Pulse to manage:

```json
[
  {
    "name": "API Server",
    "command": "cd ~/projects/myapp && npm start",
    "port": 3000,
    "logFile": "/tmp/api-server.log",
    "autostart": true
  },
  {
    "name": "Background Worker",
    "command": "node ~/projects/myapp/worker.js",
    "pidFile": "/tmp/worker.pid",
    "logFile": "/tmp/worker.log",
    "autostart": false
  },
  {
    "name": "Dev UI",
    "command": "cd ~/projects/myapp/ui && npx vite",
    "port": 5173,
    "portlessName": "myapp",
    "autostart": true
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name in the menu bar |
| `command` | string | Shell command to start the process |
| `port` | number? | TCP port to check for liveness |
| `pidFile` | string? | Path to a PID file (alternative to port check) |
| `logFile` | string? | Where to write stdout/stderr |
| `autostart` | bool | Start automatically on "Restart All" |
| `portlessName` | string? | If set, wraps the command with [Portless](https://github.com/nicholasgasior/portless) for `.localhost` routing |

### Providers (`~/.pulse/providers.json`)

Configure which AI quota providers to track:

```json
[
  {
    "provider": "claude-code",
    "displayName": "Claude Code",
    "source": "cli",
    "enabled": true
  },
  {
    "provider": "codex",
    "displayName": "Codex (OpenAI)",
    "source": "auto",
    "enabled": true
  },
  {
    "provider": "openrouter",
    "displayName": "OpenRouter",
    "source": "api",
    "apiKey": "sk-or-v1-your-key-here",
    "enabled": true
  }
]
```

## Supported quota providers

| Provider | How it works |
|----------|-------------|
| **Claude Code** | Reads OAuth token from macOS Keychain, hits the Anthropic usage API. Shows session (5h) and weekly (7d) utilization with reset timers. Requires `claude login` to have been run. |
| **Codex (OpenAI)** | Runs `openclaw status --json` to get context window usage and model info. |
| **OpenRouter** | Calls `/api/v1/auth/key` with your API key. Shows credits used vs limit. |

## Features

### Service management
- Start, stop, restart individual services or all at once
- Port-based and PID-based liveness detection
- Portless integration for `.localhost` routing
- Startup feedback: orange "starting" indicator while booting, red "FAILED" with error details if it doesn't come up
- Process tree cleanup on stop (no orphan child processes)

### Quota tracking
- Live usage bars with color coding (green/yellow/red)
- Reset countdowns for time-based limits
- Automatic retry on rate limits (429)
- Polls every 5 minutes to stay within API limits

### Session management
- **Reset Session** button clears OpenClaw agent sessions and restarts the gateway, forcing a fresh context reload for skill/config changes

### Adding services and providers

Edit `~/.pulse/services.json` and `~/.pulse/providers.json` directly, then hit **Reload Config** in the menu bar.

Or use the helper scripts:

```bash
scripts/add-service.sh    # interactive: add a service
scripts/add-provider.sh   # interactive: add a quota provider
```

### Adding a new fetcher

Create a fetcher in `Sources/Quotas/Fetchers/`, return a `QuotaStatus`, and add the case to `QuotaManager.fetchQuota(for:)`.

## Architecture

```
Sources/
├── App/
│   ├── PulseApp.swift          # Entry point, menu bar setup
│   └── MenuBarView.swift       # Tab switcher (Services | Quotas)
├── Services/
│   ├── ServiceManager.swift    # Process lifecycle, port/PID monitoring
│   └── ServiceRowView.swift    # Per-service UI row with status indicators
├── Quotas/
│   ├── QuotaManager.swift      # Parallel fetching, poll timer
│   ├── QuotaState.swift        # Data models (QuotaTier, QuotaData)
│   ├── QuotaConfig.swift       # providers.json loader
│   ├── QuotaRowView.swift      # Per-provider UI with usage bars
│   ├── QuotaDefinition.swift   # Provider config model
│   └── Fetchers/
│       ├── ClaudeCodeFetcher.swift
│       ├── CodexFetcher.swift
│       └── OpenRouterFetcher.swift
└── Shared/
    ├── Config.swift             # ~/.pulse/ bootstrap + services.json loader
    ├── ProcessUtil.swift        # Port checks, PID management, process spawning
    └── ServiceDefinition.swift  # Service config model
```

- Pure SwiftUI with `@Observable` (no Combine, no ObservableObject)
- No external dependencies — just Foundation and SwiftUI
- Services polled every 30s, quotas every 5 minutes
- Single batched `lsof` call per poll cycle (not per-service)
- Runs as a menu bar-only app (no Dock icon)

## Memory usage

Pulse typically uses 15-25 MB of RAM. No web views, no Electron, no embedded browser.

## License

MIT
