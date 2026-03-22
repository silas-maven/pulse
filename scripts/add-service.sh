#!/bin/bash
set -euo pipefail

# Add a service to ~/.pulse/services.json interactively.

PULSE_DIR="$HOME/.pulse"
SERVICES_FILE="$PULSE_DIR/services.json"

BOLD='\033[1m'
GREEN='\033[0;32m'
DIM='\033[2m'
NC='\033[0m'

if [[ ! -f "$SERVICES_FILE" ]]; then
    echo "No services.json found. Run install.sh first."
    exit 1
fi

echo -e "${BOLD}Add a new service to Pulse${NC}"
echo ""

echo -ne "  Name: "
read -r name

echo -ne "  Command: "
read -r cmd

echo -ne "  Port (leave empty if none): "
read -r port

echo -ne "  Log file [/tmp/${name// /-}.log]: "
read -r logfile
logfile="${logfile:-/tmp/${name// /-}.log}"

echo -ne "  Autostart? [y/N] "
read -r auto
auto="${auto:-N}"
auto_bool="false"
[[ "$auto" =~ ^[Yy] ]] && auto_bool="true"

port_val="null"
[[ -n "$port" ]] && port_val="$port"

python3 -c "
import json
with open('$SERVICES_FILE') as f:
    services = json.load(f)
services.append({
    'name': '''$name''',
    'command': '''$cmd''',
    'port': $port_val,
    'logFile': '''$logfile''',
    'autostart': $auto_bool
})
with open('$SERVICES_FILE', 'w') as f:
    json.dump(services, f, indent=2)
"

echo ""
echo -e "${GREEN}✓${NC} Added ${BOLD}$name${NC}"
echo -e "${DIM}  Reload config in Pulse to pick up the change.${NC}"
