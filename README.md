# vibe-local (LM Studio Support)

> **⚠️ これは [ochyai/vibe-local](https://github.com/ochyai/vibe-local) のLM Studio対応版です**
>
> 本家の `lm-studio-support` ブランチをベースに、LM StudioのOpenAI互換APIに対応させたフォークです。

---

```
    ██╗   ██╗██╗██████╗ ███████╗
    ██║   ██║██║██╔══██╗██╔════╝
    ██║   ██║██║██████╔╝█████╗
    ╚██╗ ██╔╝██║██╔══██╗██╔══╝
     ╚████╔╝ ██║██████╔╝███████╗
      ╚═══╝  ╚═╝╚═════╝ ╚══════╝
              ██╗      ██████╗  ██████╗ █████╗ ██╗
              ██║     ██╔═══██╗██╔════╝██╔══██╗██║
              ██║     ██║   ██║██║     ███████║██║
              ██║     ██║   ██║██║     ██╔══██║██║
              ███████╗╚██████╔╝╚██████╗██║  ██║███████╗
              ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝
```

> **無料のAIコーディングエージェント（オフライン・ローカル・オープンソース）**
>
> Python標準ライブラリのみで構成された単一ファイル実装。APIキー不要、クラウド不要、追加コスト不要。

オフラインのワークショップでAIエージェントを使って学習者をサポートしたり、有料プランに未加入の学生がエージェントコーディングを練習したり、ネットワークのない環境で自然言語を使ってターミナル操作を学んだり――そんな場面を想定した、非営利の研究・教育目的のユーティリティツールです。

---

## 日本語

### これは何？

MacやWindows、LinuxにコマンドをコピペするだけでAIがコードを書いてくれる環境。
ネットワーク不要・完全無料。**Python + LM Studio だけで動く**完全OSSのコーディングエージェント。

**エージェントのコア `vibe-coder.py` は Python 標準ライブラリだけで書かれた単一ファイルです。** pip install 不要、外部パッケージ依存ゼロ。ソースコードはそのまま読めるため、AIコーディングエージェントの仕組みを学ぶ教材としても、研究のベースラインとしても使えます。すべてがオープンソース (MIT) で公開されています。

```
vibe-local → vibe-coder.py (OSS, Python stdlib only, ~7400行) → LM Studio (直接通信)
```

ログイン不要・Node.js不要・プロキシプロセス不要。16個の内蔵ツール、サブエージェント、並列エージェント、ファイル監視、画像・PDF読み取り対応。MCP連携・スキルシステム・Plan/Actモード・Gitチェックポイント・自動テスト・固定フッター(DECSTBM)搭載。787テスト。

### インストール (3ステップ)

**1.** ターミナルを開く（Mac: Spotlight `Cmd+Space` → "ターミナル"で検索 / Windows: PowerShellを開く）

**2.** 以下をコピペしてEnter:

*Mac / Linux / Windows(WSL) の場合:*
```bash
curl -fsSL https://raw.githubusercontent.com/tsumuG-iso/vibe-local/lm-studio-support/install.sh | bash
```

*Windows (PowerShell) の場合:*
```powershell
Invoke-Expression (Invoke-RestMethod -Uri https://raw.githubusercontent.com/tsumuG-iso/vibe-local/lm-studio-support/install.ps1)
```

**3.** 新しいターミナルを開いて起動:

```bash
vibe-local
```

> **注意:** 本家のインストールURLは使用しないでください。上記のURLを使用してください。

### 使い方

```bash
# 対話モード（AIと会話しながらコーディング）
vibe-local

# ワンショット（1回だけ質問）
vibe-local -p "Pythonでじゃんけんゲーム作って"

# モデルを手動指定
vibe-local --model qwen3:8b

# ヘルプを表示
vibe-local --help
```

### LM Studioの初期設定

vibe-localはLM Studioをデフォルトで使用します。初回使用時に以下を設定してください：

**1. LM Studioをインストール**
https://lmstudio.ai/ からダウンロードしてインストール

**2. LM Studioを起動してAPI Serverを有効化**
- LM Studioアプリを起動
- 左サイドバーの Settings → API Server を有効化
- Portが `1234` であることを確認（デフォルト）

**3. 起動**
```bash
vibe-local
```

### アンインストール

vibe-localを削除するには以下を実行します:

> **クローンディレクトリは不要です。どこからでも実行できます。**

```bash
# 確認あり
vibe-local uninstall

# 確認なし（即時削除）
vibe-local uninstall -y
```

**別名コマンド（インストール済み環境）**
```bash
vibe-local-uninstall
vibe-local-uninstall -y
```

**手動で削除する場合:**
```bash
# macOS / Linux / WSL
rm -rf ~/.config/vibe-local
rm -rf ~/.local/state/vibe-local
rm -rf ~/.local/lib/vibe-local
rm -f ~/.local/bin/vibe-local
rm -f ~/.local/bin/vibe-coder
rm -f ~/.local/bin/vibe-local-uninstall

# Windows (PowerShell)
Remove-Item -Path "$env:USERPROFILE\.config\vibe-local" -Recurse -Force
Remove-Item -Path "$env:LOCALAPPDATA\vibe-local" -Recurse -Force
Remove-Item -Path "$env:USERPROFILE\.local\lib\vibe-local" -Recurse -Force
Remove-Item -Path "$env:USERPROFILE\.local\bin\vibe-local.cmd" -Force
Remove-Item -Path "$env:USERPROFILE\.local\bin\vibe-local.ps1" -Force
Remove-Item -Path "$env:USERPROFILE\.local\bin\vibe-local-uninstall.cmd" -Force
Remove-Item -Path "$env:USERPROFILE\.local\bin\vibe-local-uninstall.ps1" -Force
```

> **注:** LM Studioは削除されません。これらを削除する場合は別途行ってください。

### 対応環境

| 環境 | メモリ | メインモデル | サイドカー | 備考 |
|------|--------|-------------|-----------|------|
| Apple Silicon Mac (M1以降) | 96GB+ | gpt-oss:120b | qwen3-coder:30b | **最速推奨** ~70tok/s |
| Apple Silicon Mac (M1以降) | 32GB+ | qwen3-coder:30b | qwen3:8b | 推奨 |
| Apple Silicon Mac (M1以降) | 16GB | qwen3:8b | qwen3:1.7b | 十分実用的 |
| Apple Silicon Mac (M1以降) | 8GB | qwen3:1.7b | なし | 最低限動作 |
| Intel Mac | 16GB+ | qwen3:8b | qwen3:1.7b | 動作するが遅め |
| Windows (ネイティブ) | 16GB+ | qwen3:8b | qwen3:1.7b | NVIDIA GPU推奨 |
| Windows (WSL2) | 16GB+ | qwen3:8b | qwen3:1.7b | NVIDIA GPU推奨 |
| Linux (x86_64/arm64) | 16GB+ | qwen3:8b | qwen3:1.7b | NVIDIA GPU推奨 |

> サイドカーモデル = 権限チェックや初期化プローブなど軽量タスク用。自動選択されます。

### トラブルシューティング

<details>
<summary>よくある問題と解決法</summary>

**"LM Studio API Serverが起動していません"**
- LM Studioアプリを起動
- Settings → API Server を有効化
- Portが `1234` であることを確認

**"モデルが見つかりません"**
- LM Studioでモデルがロードされているか確認
- モデル名が正しいか確認

**"vibe-coder.py が見つかりません"**
```bash
# 再インストール
curl -fsSL https://raw.githubusercontent.com/tsumuG-iso/vibe-local/lm-studio-support/install.sh | bash
```

**モデルを変更したい**
```bash
nano ~/.config/vibe-local/config
# MODEL="qwen3:8b" を変更
# SIDECAR_MODEL="qwen3:1.7b"  # 軽量タスク用（省略可・自動選択）
```

**デバッグログを確認したい**
```bash
VIBE_LOCAL_DEBUG=1 vibe-local
```

**フッター（ステータス行）が崩れる**
```bash
# スクロール領域を無効にする
VIBE_NO_SCROLL=1 vibe-local
```

**ターミナル描画のデバッグ**
```bash
# エスケープシーケンスをログに記録
VIBE_DEBUG_TUI=1 vibe-local
# ログ: ~/.vibe-tui-debug.log
```

**対話中にスクロール領域を診断**
```
> /debug-scroll
```

</details>
