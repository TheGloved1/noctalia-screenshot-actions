#!/usr/bin/env bash
# install.sh — Symlink repo into Noctalia's plugin dir
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ID="$(grep -Po '^id\s*=\s*"\K[^"]+' "$REPO_DIR/plugin.toml")"
LINK_NAME="$HOME/.local/share/noctalia/plugins/$PLUGIN_ID"
PARENT_DIR="$(dirname "$LINK_NAME")"

mkdir -p "$PARENT_DIR"
ln -sfn "$REPO_DIR" "$LINK_NAME"
echo "✓ Installed: $LINK_NAME -> $REPO_DIR"