#!/bin/bash
# uninstall.sh
# vibe-localをアンインストールするスクリプト
#
# 使い方:
#   uninstall.sh
#
# 警告: このスクリプトはvibe-localのファイルを削除します

set -euo pipefail

# Colors
RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
CYAN='\033[38;5;51m'
NC='\033[0m'

# Directories to remove (installed by install.sh)
CONFIG_DIR="${HOME}/.config/vibe-local"
STATE_DIR="${HOME}/.local/state/vibe-local"
LIB_DIR="${HOME}/.local/lib/vibe-local"
BIN_DIR="${HOME}/.local/bin"

# Current directory (for clone directory removal)
CURRENT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

echo ""
echo "============================================"
echo " 🗑️  vibe-local アンインストール"
echo "============================================"
echo ""
echo "${YELLOW}⚠️  以下のファイルが削除されます:${NC}"
echo "  - $CONFIG_DIR"
echo "  - $STATE_DIR"
echo "  - $LIB_DIR"
echo "  - $BIN_DIR/vibe-local"
echo "  - $BIN_DIR/vibe-coder"

# Check if current directory is a vibe-local clone
if [ -n "$SCRIPT_DIR" ] && [ "$(cd "$SCRIPT_DIR" 2>/dev/null && git remote -v 2>/dev/null | grep -q vibe-local)" ]; then
    echo "  - $SCRIPT_DIR (クローンディレクトリ)"
fi
echo ""
echo -n "本当に削除しますか？ [y/N]: "
read -r REPLY
echo ""

if [[ ! "$REPLY" =~ ^[yY]$ ]]; then
    echo "${YELLOW}キャンセルしました${NC}"
    exit 0
fi

echo "${CYAN}削除中...${NC}"

# Remove config
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    echo "  ✓ $CONFIG_DIR"
fi

# Remove state
if [ -d "$STATE_DIR" ]; then
    rm -rf "$STATE_DIR"
    echo "  ✓ $STATE_DIR"
fi

# Remove lib
if [ -d "$LIB_DIR" ]; then
    rm -rf "$LIB_DIR"
    echo "  ✓ $LIB_DIR"
fi

# Remove binaries
for bin_file in "$BIN_DIR/vibe-local" "$BIN_DIR/vibe-coder"; do
    if [ -f "$bin_file" ] || [ -L "$bin_file" ]; then
        rm -f "$bin_file"
        echo "  ✓ $bin_file"
    fi
done

# Remove clone directory if script is run from within it
if [ -n "$SCRIPT_DIR" ] && [ -n "$CURRENT_DIR" ]; then
    if [ "$CURRENT_DIR" = "$SCRIPT_DIR" ] || [[ "$CURRENT_DIR" == "$SCRIPT_DIR"/* ]]; then
        if [ -f "$SCRIPT_DIR/.git/config" ] || [ -d "$SCRIPT_DIR/.git" ]; then
            echo "${CYAN}クローンディレクトリを検出しました${NC}"
            # Move up one directory to avoid "directory not empty" error
            PARENT_DIR="$(dirname "$SCRIPT_DIR")"
            cd "$PARENT_DIR" 2>/dev/null || true
            rm -rf "$SCRIPT_DIR"
            echo "  ✓ $SCRIPT_DIR"
        fi
    fi
fi

echo ""
echo "${GREEN}✅ アンインストール完了${NC}"
echo ""
echo "注: Ollamaは削除されません。Ollamaを削除する場合は:"
echo "  macOS: 移動してOllama.appをゴミ箱へ"
echo "  Linux: which ollama で場所を確認して削除"
