#!/bin/bash
# vibe-local.sh
# ローカルLLM (Ollama) で vibe-coder を起動するスクリプト
# Python + Ollama だけで動作 — Node.js不要、Claude Code不要、プロキシ不要
#
# NOTE: This project is NOT affiliated with, endorsed by, or associated with Anthropic.
#
# 使い方:
#   vibe-local                    # インタラクティブモード
#   vibe-local -p "質問"          # ワンショット
#   vibe-local uninstall          # アンインストール
#   vibe-local --auto             # ネットワーク状況で自動判定
#   vibe-local --model qwen3:8b   # モデル手動指定
#   vibe-local -y                 # パーミッション確認スキップ (自己責任)
#   vibe-local --debug            # デバッグモード

# NOTE: set -e を使わない (途中停止を防ぐ)
set -uo pipefail

# --- ディレクトリ初期化 ---
STATE_DIR="${HOME}/.local/state/vibe-local"
mkdir -p "$STATE_DIR" 2>/dev/null || true
chmod 700 "$STATE_DIR" 2>/dev/null || true

# --- 設定読み込み (安全なパーサー) ---
CONFIG_FILE="${HOME}/.config/vibe-local/config"
LIB_DIR="${HOME}/.local/lib/vibe-local"
VIBE_CODER_SCRIPT="${LIB_DIR}/vibe-coder.py"

# デフォルト値
MODEL=""
SIDECAR_MODEL=""
LLM_ENGINE="lmstudio"  # デフォルトはLM Studio
OLLAMA_HOST="http://localhost:11434"
VIBE_LOCAL_DEBUG=0

# LM Studio用デフォルト設定
LMSTUDIO_HOST="http://localhost:1234"
LMSTUDIO_API_PATH="/v1"

run_uninstall() {
    local auto_yes="${1:-0}"
    local config_dir="${HOME}/.config/vibe-local"
    local state_dir="${HOME}/.local/state/vibe-local"
    local lib_dir="${HOME}/.local/lib/vibe-local"
    local bin_dir="${HOME}/.local/bin"
    local targets=(
        "$config_dir"
        "$state_dir"
        "$lib_dir"
        "$bin_dir/vibe-local"
        "$bin_dir/vibe-coder"
        "$bin_dir/vibe-local-uninstall"
    )
    local removed=0

    echo ""
    echo "============================================"
    echo " 🗑️  vibe-local Uninstall"
    echo "============================================"
    echo ""
    echo "削除対象:"
    printf '  - %s\n' "${targets[@]}"
    echo ""

    if [ "$auto_yes" -ne 1 ]; then
        printf "本当に削除しますか？ [y/N]: "
        read -r reply </dev/tty 2>/dev/null || read -r reply 2>/dev/null || reply="n"
        case "$reply" in
            [yY]|[yY][eE][sS]|はい|是) ;;
            *)
                echo "キャンセルしました。"
                return 0
                ;;
        esac
    fi

    for path in "${targets[@]}"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            rm -rf "$path" 2>/dev/null || true
            if [ ! -e "$path" ] && [ ! -L "$path" ]; then
                echo "  ✓ $path"
                removed=$((removed + 1))
            else
                echo "  ! 削除できませんでした: $path"
            fi
        fi
    done

    echo ""
    if [ "$removed" -gt 0 ]; then
        echo "✅ アンインストール完了"
    else
        echo "ℹ️ 削除対象は見つかりませんでした"
    fi
    echo "注: LM Studio / Ollama 本体は削除しません。"
}

# [C1 fix] source ではなく grep + cut で既知キーのみ安全に読む
# cut is safer than sed for values containing special characters
if [ -f "$CONFIG_FILE" ]; then
    _val() { grep -E "^${1}=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' | sed "s/^[\"']//;s/[\"'[:space:]]*$//;s/[[:space:]]*#.*//" || true; }
    _m="$(_val MODEL)"
    _s="$(_val SIDECAR_MODEL)"
    _e="$(_val LLM_ENGINE)"
    _h="$(_val OLLAMA_HOST)"
    _l="$(_val LMSTUDIO_HOST)"
    _d="$(_val VIBE_LOCAL_DEBUG)"
    [ -n "$_m" ] && MODEL="$_m"
    [ -n "$_s" ] && SIDECAR_MODEL="$_s"
    [ -n "$_e" ] && LLM_ENGINE="$_e"
    [ -n "$_h" ] && OLLAMA_HOST="$_h"
    [ -n "$_l" ] && LMSTUDIO_HOST="$_l"
    [ -n "$_d" ] && VIBE_LOCAL_DEBUG="$_d"
    unset -f _val
    unset _m _s _e _h _l _d
fi

# --- 環境変数から設定を読み込み ---
[ -n "$VIBE_LOCAL_ENGINE" ] && LLM_ENGINE="$VIBE_LOCAL_ENGINE"
[ -n "$LMSTUDIO_HOST" ] && true || LMSTUDIO_HOST="http://localhost:1234"

# Uninstall should work even when python/vibe-coder are missing.
if [[ "${1:-}" == "uninstall" || "${1:-}" == "remove" || "${1:-}" == "--uninstall" ]]; then
    _u_yes=0
    for _arg in "$@"; do
        case "$_arg" in
            -y|--yes|--dangerously-skip-permissions) _u_yes=1 ;;
        esac
    done
    run_uninstall "$_u_yes"
    exit 0
fi


# --- python3 存在確認 ---
if ! command -v python3 &>/dev/null; then
    echo "❌ エラー: python3 が見つかりません"
    echo ""
    echo "インストール方法:"
    echo "  macOS: brew install python3"
    echo "  Ubuntu/Debian: sudo apt-get install python3"
    echo "  Fedora: sudo dnf install python3"
    exit 1
fi

# --- vibe-coder.py の探索 ---
if [ ! -f "$VIBE_CODER_SCRIPT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
    if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/vibe-coder.py" ]; then
        VIBE_CODER_SCRIPT="${SCRIPT_DIR}/vibe-coder.py"
    else
        echo "エラー: vibe-coder.py が見つかりません"
        echo "  install.sh を実行するか、vibe-coder.py を同じディレクトリに置いてください"
        exit 1
    fi
fi

# --- LLMエンジン (LM Studio) が起動しているか確認 ---
ensure_llm_engine() {
    ensure_lmstudio
}

ensure_lmstudio() {
    # LM Studio API Serverの確認
    local api_endpoint="$LMSTUDIO_HOST${LMSTUDIO_API_PATH}/models"
    if curl -s --max-time 2 "$api_endpoint" &>/dev/null; then
        return 0
    fi

    echo "❌ エラー: LM Studio API Serverが起動していません"
    echo ""
    echo "対処法:"
    echo "  1. LM Studioを起動してください"
    echo "  2. Settings → API Server を有効にしてください"
    echo "  3. Portが $LMSTUDIO_HOST であることを確認してください"
    return 1
}

# --- ネットワーク接続チェック ---
check_network() {
    curl -s --max-time 3 https://api.anthropic.com/ &>/dev/null
}

# --- 引数パース ---
AUTO_MODE=0
YES_FLAG=0
UNINSTALL_MODE=0
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=1
            shift
            ;;
        uninstall|remove|--uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --model)
            if [[ $# -lt 2 ]]; then
                echo "Error: --model requires an argument"
                exit 1
            fi
            MODEL="$2"
            shift 2
            ;;
        --engine)
            if [[ $# -lt 2 ]]; then
                echo "Error: --engine requires an argument (ollama or lmstudio)"
                exit 1
            fi
            ENGINE="$2"
            if [[ "$ENGINE" != "ollama" && "$ENGINE" != "lmstudio" ]]; then
                echo "Error: --engine must be 'ollama' or 'lmstudio'"
                exit 1
            fi
            LLM_ENGINE="$ENGINE"
            shift 2
            ;;
        -y|--yes|--dangerously-skip-permissions)
            YES_FLAG=1
            shift
            ;;
        --debug)
            VIBE_LOCAL_DEBUG=1
            shift
            ;;
        -h|--help)
            cat <<'HELP'
vibe-local - Free AI Coding Agent for Local LLMs

使い方:
  vibe-local                    # インタラクティブモード
  vibe-local -p "質問"          # ワンショット
  vibe-local uninstall          # アンインストール
  vibe-local --auto             # ネットワーク状況で自動判定
  vibe-local --model <name>     # モデル手動指定
  vibe-local -y                 # パーミッション確認スキップ (自己責任)
  vibe-local --debug            # デバッグモード

LLMエンジン:
  lmstudio    - LM Studioを使用 (デフォルト)

設定ファイル:
  ~/.config/vibe-local/config
  設定例:
    LLM_ENGINE=lmstudio
    MODEL=qwen3.5-9b

環境変数:
  VIBE_LOCAL_ENGINE=lmstudio     # LLMエンジンを指定
  VIBE_LOCAL_DEBUG=1             # デバッグモードを有効化

詳細: https://github.com/tsumuG-iso/vibe-local/tree/lm-studio-support
HELP
            exit 0
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$UNINSTALL_MODE" -eq 1 ]; then
    run_uninstall "$YES_FLAG"
    exit 0
fi

# --- 自動判定モード ---
if [ "$AUTO_MODE" -eq 1 ]; then
    if check_network; then
        # Check if claude CLI exists
        if command -v claude &>/dev/null; then
            echo "🌐 ネットワーク接続あり + Claude Code あり → Claude Code を起動"
            _claude_args=()
            [ "$YES_FLAG" -eq 1 ] && _claude_args+=(--dangerously-skip-permissions)
            exec claude ${_claude_args[@]+"${_claude_args[@]}"} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
        fi
        echo "🌐 ネットワーク接続あり (Claude Code なし) → ローカルモードで起動"
    else
        echo "📡 ネットワーク接続なし → ローカルモード"
    fi
fi

# --- ローカルモードで起動 ---
if ! ensure_llm_engine; then
    echo ""
    echo "LLMエンジンが起動できないため終了します。"
    exit 1
fi

# モデル引数を組み立て
MODEL_ARGS=()
if [ -n "$MODEL" ]; then
    MODEL_ARGS+=(--model "$MODEL")
fi

# --- パーミッション確認 ---
PERM_ARGS=()

if [ "$YES_FLAG" -eq 1 ]; then
    PERM_ARGS+=(-y)
else
    echo ""
    echo "============================================"
    echo " ⚠️  パーミッション確認 / Permission Check"
    echo "============================================"
    echo ""
    echo " vibe-local はツール自動許可モード (-y) で起動できます。"
    echo ""
    echo " This means the AI can execute commands, read/write"
    echo " files, and modify your system WITHOUT asking."
    echo ""
    echo " ローカルLLMはクラウドAIより精度が低いため、"
    echo " 意図しない操作が実行される可能性があります。"
    echo ""
    echo "--------------------------------------------"
    echo " [y] 自動許可モード (Auto-approve all tools)"
    echo " [N] 通常モード (Ask before each tool use)"
    echo "--------------------------------------------"
    echo ""
    printf " 続行しますか？ / Continue? [y/N]: "
    read -r -t 30 REPLY </dev/tty 2>/dev/null || read -r -t 30 REPLY 2>/dev/null || REPLY="n"
    echo ""

    case "$REPLY" in
        [yY]|[yY][eE][sS]|はい|是)
            PERM_ARGS+=(-y)
            echo " → 自動許可モードで起動します"
            ;;
        *)
            echo " → 通常モード (毎回確認) で起動します"
            ;;
    esac
fi

DEBUG_ARGS=()
if [ "$VIBE_LOCAL_DEBUG" = "1" ] || [ "$VIBE_LOCAL_DEBUG" = "true" ]; then
    DEBUG_ARGS+=(--debug)
fi

# --- 起動 ---
echo ""
echo "============================================"
echo " 🤖 vibe-local (vibe-coder)"
if [ -n "$MODEL" ]; then
    echo " Model: $MODEL"
else
    echo " Model: (auto-detect)"
fi
echo " Engine: LM Studio ($LMSTUDIO_HOST${LMSTUDIO_API_PATH})"
echo "============================================"
echo ""

# LLM_ENGINEに応じて環境変数を設定
if [ "$LLM_ENGINE" = "lmstudio" ]; then
    OLLAMA_HOST="$LMSTUDIO_HOST${LMSTUDIO_API_PATH}"
fi

OLLAMA_HOST="$OLLAMA_HOST" \
VIBE_LOCAL_ENGINE="$LLM_ENGINE" \
VIBE_LOCAL_MODEL="${MODEL:-}" \
VIBE_LOCAL_SIDECAR_MODEL="${SIDECAR_MODEL:-}" \
VIBE_LOCAL_DEBUG="${VIBE_LOCAL_DEBUG:-0}" \
exec python3 "$VIBE_CODER_SCRIPT" \
    ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
    ${PERM_ARGS[@]+"${PERM_ARGS[@]}"} \
    ${DEBUG_ARGS[@]+"${DEBUG_ARGS[@]}"} \
    ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
