#!/bin/bash
set -euo pipefail

# Pulse installer
# Builds from source, installs the binary, and runs interactive setup.

PULSE_DIR="$HOME/.pulse"
INSTALL_DIR="/usr/local/bin"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}▸${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }
err()   { echo -e "${RED}✗${NC} $1"; }
header(){ echo -e "\n${BOLD}$1${NC}"; }

# ─── Preflight ───────────────────────────────────────────────────────

header "Pulse Installer"
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    err "Pulse is macOS-only. Detected: $(uname)"
    exit 1
fi

# Check macOS version (need 14+)
macos_version=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$macos_version" -lt 14 ]]; then
    err "Pulse requires macOS 14 (Sonoma) or later. You have $(sw_vers -productVersion)."
    exit 1
fi

# Check Swift
if ! command -v swift &>/dev/null; then
    err "Swift not found. Install Xcode or Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

swift_version=$(swift --version 2>&1 | head -1)
ok "Swift found: $swift_version"

# ─── Build ───────────────────────────────────────────────────────────

header "Building Pulse"

cd "$REPO_DIR"
info "Compiling (release mode)..."
swift build -c release 2>&1 | tail -3

BINARY="$REPO_DIR/.build/release/Pulse"
if [[ ! -f "$BINARY" ]]; then
    err "Build failed — binary not found at $BINARY"
    exit 1
fi

ok "Built successfully"

# ─── Install binary ──────────────────────────────────────────────────

header "Installing"

echo -e "Install binary to ${DIM}$INSTALL_DIR/pulse${NC}? [Y/n] "
read -r install_choice
install_choice="${install_choice:-Y}"

if [[ "$install_choice" =~ ^[Yy] ]]; then
    if [[ -w "$INSTALL_DIR" ]]; then
        cp "$BINARY" "$INSTALL_DIR/pulse"
    else
        info "Need sudo to write to $INSTALL_DIR"
        sudo cp "$BINARY" "$INSTALL_DIR/pulse"
    fi
    ok "Installed to $INSTALL_DIR/pulse"
else
    info "Skipped. You can run it directly: $BINARY"
fi

# ─── Config directory ────────────────────────────────────────────────

header "Configuration"

mkdir -p "$PULSE_DIR"
ok "Config directory: $PULSE_DIR"

# ─── Provider setup ──────────────────────────────────────────────────

header "Quota Providers"
echo "Which AI coding tool quotas do you want to track?"
echo ""

providers="[]"

# Claude Code
echo -ne "  ${BOLD}Claude Code${NC} (reads OAuth token from Keychain) [Y/n] "
read -r claude_choice
claude_choice="${claude_choice:-Y}"
if [[ "$claude_choice" =~ ^[Yy] ]]; then
    providers=$(echo "$providers" | python3 -c "
import json, sys
p = json.load(sys.stdin)
p.append({'provider': 'claude-code', 'displayName': 'Claude Code', 'source': 'cli', 'enabled': True})
json.dump(p, sys.stdout)
")
    ok "Claude Code enabled"
fi

# Codex / OpenAI
echo -ne "  ${BOLD}Codex (OpenAI)${NC} (requires openclaw CLI) [y/N] "
read -r codex_choice
codex_choice="${codex_choice:-N}"
if [[ "$codex_choice" =~ ^[Yy] ]]; then
    if command -v openclaw &>/dev/null; then
        ok "openclaw CLI found"
    else
        warn "openclaw CLI not found — provider will error until installed"
    fi
    providers=$(echo "$providers" | python3 -c "
import json, sys
p = json.load(sys.stdin)
p.append({'provider': 'codex', 'displayName': 'Codex (OpenAI)', 'source': 'auto', 'enabled': True})
json.dump(p, sys.stdout)
")
    ok "Codex enabled"
fi

# OpenRouter
echo -ne "  ${BOLD}OpenRouter${NC} (requires API key) [y/N] "
read -r or_choice
or_choice="${or_choice:-N}"
if [[ "$or_choice" =~ ^[Yy] ]]; then
    echo -ne "    API key (sk-or-...): "
    read -r or_key
    if [[ -z "$or_key" ]]; then
        warn "No key provided — provider disabled. Add it later in ~/.pulse/providers.json"
        providers=$(echo "$providers" | python3 -c "
import json, sys
p = json.load(sys.stdin)
p.append({'provider': 'openrouter', 'displayName': 'OpenRouter', 'source': 'api', 'apiKey': '', 'enabled': False})
json.dump(p, sys.stdout)
")
    else
        providers=$(echo "$providers" | python3 -c "
import json, sys
p = json.load(sys.stdin)
p.append({'provider': 'openrouter', 'displayName': 'OpenRouter', 'source': 'api', 'apiKey': '$or_key', 'enabled': True})
json.dump(p, sys.stdout)
")
        ok "OpenRouter enabled"
    fi
fi

# Write providers.json
echo "$providers" | python3 -m json.tool > "$PULSE_DIR/providers.json"
ok "Wrote $PULSE_DIR/providers.json"

# ─── Service setup ───────────────────────────────────────────────────

header "Services"
echo "Pulse can manage local dev processes (start/stop/restart from the menu bar)."
echo ""

services="[]"

echo -ne "Add a service now? [y/N] "
read -r add_svc
add_svc="${add_svc:-N}"

while [[ "$add_svc" =~ ^[Yy] ]]; do
    echo ""
    echo -ne "  Name: "
    read -r svc_name

    echo -ne "  Command: "
    read -r svc_cmd

    echo -ne "  Port (leave empty if none): "
    read -r svc_port

    echo -ne "  Log file (leave empty for /tmp/${svc_name// /-}.log): "
    read -r svc_log
    svc_log="${svc_log:-/tmp/${svc_name// /-}.log}"

    echo -ne "  Autostart on 'Restart All'? [y/N] "
    read -r svc_auto
    svc_auto="${svc_auto:-N}"
    auto_bool="false"
    [[ "$svc_auto" =~ ^[Yy] ]] && auto_bool="true"

    port_val="null"
    [[ -n "$svc_port" ]] && port_val="$svc_port"

    services=$(echo "$services" | python3 -c "
import json, sys
s = json.load(sys.stdin)
entry = {
    'name': '''$svc_name''',
    'command': '''$svc_cmd''',
    'port': $port_val,
    'logFile': '''$svc_log''',
    'autostart': $auto_bool
}
s.append(entry)
json.dump(s, sys.stdout)
")
    ok "Added: $svc_name"

    echo ""
    echo -ne "Add another service? [y/N] "
    read -r add_svc
    add_svc="${add_svc:-N}"
done

# Write services.json
echo "$services" | python3 -m json.tool > "$PULSE_DIR/services.json"
ok "Wrote $PULSE_DIR/services.json"

# ─── Launch Agent (optional) ─────────────────────────────────────────

header "Auto-start"
echo -ne "Launch Pulse automatically on login? [y/N] "
read -r launch_choice
launch_choice="${launch_choice:-N}"

if [[ "$launch_choice" =~ ^[Yy] ]]; then
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST="$PLIST_DIR/dev.pulse.app.plist"
    mkdir -p "$PLIST_DIR"

    pulse_bin="$INSTALL_DIR/pulse"
    [[ ! -f "$pulse_bin" ]] && pulse_bin="$BINARY"

    cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.pulse.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>$pulse_bin</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/pulse.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/pulse.log</string>
</dict>
</plist>
PLISTEOF
    ok "LaunchAgent written to $PLIST"
    info "It will start on next login, or run: launchctl load $PLIST"
fi

# ─── Done ────────────────────────────────────────────────────────────

echo ""
header "Done!"
echo ""
echo -e "  Config:     ${DIM}~/.pulse/${NC}"
echo -e "  Services:   ${DIM}~/.pulse/services.json${NC}"
echo -e "  Providers:  ${DIM}~/.pulse/providers.json${NC}"
echo ""
echo -e "  Run:        ${BOLD}pulse${NC}  ${DIM}(or $BINARY)${NC}"
echo -e "  Edit later: ${DIM}vim ~/.pulse/services.json${NC}"
echo ""
info "Pulse will appear in your menu bar. Click the icon to manage services and quotas."
