#!/bin/bash
# uninstall.sh
# vibe-localをアンインストールするスクリプト
#
# 使い方:
#   uninstall.sh
#   uninstall.sh -y
#
# 警告: このスクリプトはvibe-localのインストール済みファイルを削除します

set -uo pipefail

AUTO_YES=0
if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
    AUTO_YES=1
fi

CONFIG_DIR="${HOME}/.config/vibe-local"
STATE_DIR="${HOME}/.local/state/vibe-local"
LIB_DIR="${HOME}/.local/lib/vibe-local"
BIN_DIR="${HOME}/.local/bin"

TARGETS=(
    "$CONFIG_DIR"
    "$STATE_DIR"
    "$LIB_DIR"
    "$BIN_DIR/vibe-local"
    "$BIN_DIR/vibe-coder"
    "$BIN_DIR/vibe-local-uninstall"
)

echo ""
echo "============================================"
echo " 🗑️  vibe-local アンインストール"
echo "============================================"
echo ""
echo "削除対象:"
printf '  - %s\n' "${TARGETS[@]}"
echo ""

if [ "$AUTO_YES" -ne 1 ]; then
    printf "本当に削除しますか？ [y/N]: "
    read -r REPLY </dev/tty 2>/dev/null || read -r REPLY 2>/dev/null || REPLY="n"
    case "$REPLY" in
        [yY]|[yY][eE][sS]|はい|是) ;;
        *)
            echo "キャンセルしました"
            exit 0
            ;;
    esac
fi

REMOVED=0
for path in "${TARGETS[@]}"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
        rm -rf "$path" 2>/dev/null || true
        if [ ! -e "$path" ] && [ ! -L "$path" ]; then
            echo "  ✓ $path"
            REMOVED=$((REMOVED + 1))
        else
            echo "  ! 削除できませんでした: $path"
        fi
    fi
done

echo ""
if [ "$REMOVED" -gt 0 ]; then
    echo "✅ アンインストール完了"
else
    echo "ℹ️ 削除対象は見つかりませんでした"
fi
echo "注: LM Studio / Ollama は削除されません。"
