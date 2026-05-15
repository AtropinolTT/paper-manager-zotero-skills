#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MCP_DIR="$SKILL_DIR/assets/mcp-zotero"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Zotero Manager - One-time Setup"
echo "============================================"
echo ""

# --- Check Node.js ---
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js is not installed. Please install Node.js >= 18 and re-run this script.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Node.js $(node --version)"

# --- Install npm dependencies ---
echo ""
echo "Installing mcp-zotero dependencies..."
cd "$MCP_DIR"
if [ -f "package-lock.json" ]; then
    npm ci --production 2>&1 | tail -3
else
    npm install --production 2>&1 | tail -3
fi
echo -e "${GREEN}[OK]${NC} Dependencies installed"

# --- Verify build ---
if [ ! -f "$MCP_DIR/build/server.js" ]; then
    echo -e "${RED}Build output not found at build/server.js. The bundled mcp-zotero may be incomplete.${NC}"
    exit 1
fi
if [ ! -f "$MCP_DIR/build/tools/add-item-note.js" ]; then
    echo -e "${RED}add_item_note tool not found in build. The bundled mcp-zotero may be incomplete.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} mcp-zotero build verified (add_item_note available)"

# --- Collect credentials ---
echo ""
echo "Zotero API credentials are needed. Find them at:"
echo "  https://www.zotero.org/settings/keys"
echo ""
read -r -p "ZOTERO_API_KEY: " API_KEY
read -r -p "ZOTERO_USER_ID: " USER_ID

if [ -z "$API_KEY" ] || [ -z "$USER_ID" ]; then
    echo -e "${RED}Both API_KEY and USER_ID are required.${NC}"
    exit 1
fi

# --- Choose persistence ---
echo ""
echo "How would you like to store these credentials?"
echo "  1) Save to project .mcp.json (recommended)"
echo "  2) Session-only (you'll need to re-enter each session)"
read -r -p "Choice [1/2]: " PERSIST_CHOICE

if [ "$PERSIST_CHOICE" = "2" ]; then
    echo ""
    echo -e "${YELLOW}Session-only mode. Set these env vars before starting Claude Code:${NC}"
    echo "  export ZOTERO_API_KEY=$API_KEY"
    echo "  export ZOTERO_USER_ID=$USER_ID"
    echo ""
    echo "Done. You may now use the zotero-manager skill."
    exit 0
fi

# --- Find or create .mcp.json ---
# Look for .mcp.json in the current working directory (project root)
MCP_JSON="$(pwd)/.mcp.json"

if [ -f "$MCP_JSON" ]; then
    echo ""
    echo "Found existing .mcp.json at $MCP_JSON"
    echo -e "${YELLOW}Updating zotero server config...${NC}"

    # Use python3 to merge the zotero config into existing .mcp.json
    python3 - "$MCP_JSON" "$MCP_DIR" "$API_KEY" "$USER_ID" << 'PYEOF'
import json, sys

mcp_json_path = sys.argv[1]
mcp_dir = sys.argv[2]
api_key = sys.argv[3]
user_id = sys.argv[4]

with open(mcp_json_path, 'r') as f:
    config = json.load(f)

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['zotero'] = {
    "command": "node",
    "args": [f"{mcp_dir}/build/server.js"],
    "env": {
        "ZOTERO_API_KEY": api_key,
        "ZOTERO_USER_ID": user_id,
        "UNPAYWALL_EMAIL": "your@email.edu"
    }
}

with open(mcp_json_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print(f"Updated {mcp_json_path}")
PYEOF
else
    echo ""
    echo "Creating new .mcp.json at $MCP_JSON"

    python3 - "$MCP_JSON" "$MCP_DIR" "$API_KEY" "$USER_ID" << 'PYEOF'
import json, sys

mcp_json_path = sys.argv[1]
mcp_dir = sys.argv[2]
api_key = sys.argv[3]
user_id = sys.argv[4]

config = {
    "mcpServers": {
        "zotero": {
            "command": "node",
            "args": [f"{mcp_dir}/build/server.js"],
            "env": {
                "ZOTERO_API_KEY": api_key,
                "ZOTERO_USER_ID": user_id,
                "UNPAYWALL_EMAIL": "your@email.edu"
            }
        }
    }
}

with open(mcp_json_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print(f"Created {mcp_json_path}")
PYEOF
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (or reload the MCP server) to pick up the new config"
echo "  2. Try: '搜索我的Zotero库' or '把这篇文章添加到Zotero: <DOI>'"
echo ""
echo -e "${YELLOW}Credentials are stored in .mcp.json — do NOT commit this file.${NC}"
