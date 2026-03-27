#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for ionic-team/ionic-docs
# Runs on existing source tree (no clone). Installs deps, applies fixes, builds.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Node version ---
# Docusaurus 3.7.0 requires Node >=20
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    nvm use 20 2>/dev/null || nvm install 20
fi
NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
echo "[INFO] Using Node $(node --version)"
if [ "$NODE_MAJOR" -lt 20 ]; then
    echo "[ERROR] Node $NODE_MAJOR is too old; ionic-docs requires Node >=20"
    exit 1
fi

# --- Dependencies ---
echo "[INFO] Installing dependencies..."
npm install --legacy-peer-deps

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

# --- Build ---
echo "[INFO] Building Docusaurus site..."
NODE_OPTIONS="--max-old-space-size=4096" npm run build

echo "[DONE] Build complete."
