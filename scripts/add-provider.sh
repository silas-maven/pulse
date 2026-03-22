#!/bin/bash
set -euo pipefail

# Add a quota provider to ~/.pulse/providers.json interactively.

PULSE_DIR="$HOME/.pulse"
PROVIDERS_FILE="$PULSE_DIR/providers.json"

BOLD='\033[1m'
GREEN='\033[0;32m'
DIM='\033[2m'
NC='\033[0m'

if [[ ! -f "$PROVIDERS_FILE" ]]; then
    echo "No providers.json found. Run install.sh first."
    exit 1
fi

echo -e "${BOLD}Add a quota provider to Pulse${NC}"
echo ""
echo "  Supported providers:"
echo "    claude-code   — Claude Code (OAuth from Keychain)"
echo "    codex         — Codex / OpenAI (via openclaw CLI)"
echo "    openrouter    — OpenRouter (API key)"
echo ""

echo -ne "  Provider ID: "
read -r provider

echo -ne "  Display name [$provider]: "
read -r display_name
display_name="${display_name:-$provider}"

api_key=""
if [[ "$provider" == "openrouter" ]]; then
    echo -ne "  API key: "
    read -r api_key
fi

python3 -c "
import json
with open('$PROVIDERS_FILE') as f:
    providers = json.load(f)
entry = {
    'provider': '$provider',
    'displayName': '$display_name',
    'source': 'auto',
    'enabled': True
}
api_key = '$api_key'
if api_key:
    entry['apiKey'] = api_key
    entry['source'] = 'api'
providers.append(entry)
with open('$PROVIDERS_FILE', 'w') as f:
    json.dump(providers, f, indent=2)
"

echo ""
echo -e "${GREEN}✓${NC} Added ${BOLD}$display_name${NC}"
echo -e "${DIM}  Reload config in Pulse to pick up the change.${NC}"
