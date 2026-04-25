#!/bin/bash
# setup-brainbank.sh - 安装并初始化本地向量知识库 (BrainBank / ChromaDB)
# 使用独立虚拟环境，兼容 macOS Homebrew Python (PEP 668)
set -e

HARNESS_DIR=".harness"
VENV_DIR="$HARNESS_DIR/.venv"
BB_SCRIPT="$HARNESS_DIR/scripts/bb"
DB_PATH="$HARNESS_DIR/.brainbank"
ENV_FILE="$HARNESS_DIR/.env"

echo "========================================"
echo " BrainBank 初始化向导"
echo "========================================"

# ── 步骤 1: 检查 Python ──────────────────────
if ! command -v python3 &>/dev/null; then
    echo "⚠ 未检测到 python3，BrainBank 不可用。"
    echo "  安装: brew install python3"
    echo "  降级方案: 在 Cursor 中使用 @Codebase 语义检索替代。"
    grep -v "^BB_AVAILABLE" "$ENV_FILE" 2>/dev/null > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "$ENV_FILE" || true
    echo "BB_AVAILABLE=false" >> "$ENV_FILE"
    exit 0
fi

PYTHON=$(command -v python3)
echo "✅ Python: $($PYTHON --version)"

# ── 步骤 2: 创建虚拟环境 ─────────────────────
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 创建虚拟环境: $VENV_DIR"
    $PYTHON -m venv "$VENV_DIR"
    echo "✅ 虚拟环境已创建"
else
    echo "✅ 虚拟环境已存在: $VENV_DIR"
fi

VENV_PYTHON="$VENV_DIR/bin/python3"
VENV_PIP="$VENV_DIR/bin/pip"

# ── 步骤 3: 在虚拟环境中安装 chromadb ────────
if ! "$VENV_PYTHON" -c "import chromadb" 2>/dev/null; then
    echo "📦 在虚拟环境中安装 chromadb..."
    if "$VENV_PIP" install "chromadb>=0.5.0" --quiet; then
        echo "✅ chromadb 安装成功"
    else
        echo "⚠ chromadb 安装失败。"
        echo "  可手动执行: source $VENV_DIR/bin/activate && pip install chromadb"
        echo "  降级方案: 使用 @Codebase 语义检索。"
        grep -v "^BB_AVAILABLE" "$ENV_FILE" 2>/dev/null > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "$ENV_FILE" || true
        echo "BB_AVAILABLE=false" >> "$ENV_FILE"
        exit 0
    fi
else
    CHROMA_VER=$("$VENV_PYTHON" -c "import chromadb; print(chromadb.__version__)" 2>/dev/null)
    echo "✅ chromadb 已安装: v${CHROMA_VER}"
fi

# ── 步骤 4: 更新 bb 脚本 shebang 指向 venv ───
# 将 bb 脚本首行替换为 venv 中的 Python 绝对路径
BB_ABS_VENV_PYTHON="$(pwd)/$VENV_DIR/bin/python3"
# 用 sed 替换第一行 shebang（兼容 macOS BSD sed）
sed -i.bak "1s|.*|#!${BB_ABS_VENV_PYTHON}|" "$BB_SCRIPT" && rm -f "${BB_SCRIPT}.bak"
chmod +x "$BB_SCRIPT"
echo "✅ bb 脚本已指向虚拟环境 Python: $BB_ABS_VENV_PYTHON"

# ── 步骤 5: 注册 bb 命令到 PATH ──────────────
BB_LINK=""
if [ -w "/usr/local/bin" ]; then
    ln -sf "$(pwd)/$BB_SCRIPT" /usr/local/bin/bb 2>/dev/null && BB_LINK="/usr/local/bin/bb"
fi

if [ -z "$BB_LINK" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(pwd)/$BB_SCRIPT" "$HOME/.local/bin/bb"
    BB_LINK="$HOME/.local/bin/bb"
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo ""
        echo "⚠ 请将以下行加入 ~/.zshrc 或 ~/.bashrc，然后重启终端："
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi
fi

echo "✅ bb 命令已注册: $BB_LINK"

# ── 步骤 6: 初始化向量库 ─────────────────────
mkdir -p "$DB_PATH"
"$BB_SCRIPT" --db-path "$DB_PATH" init

# ── 步骤 7: 写入 .env 标记 ───────────────────
grep -v "^BB_AVAILABLE\|^BB_DB_PATH\|^BB_VENV" "$ENV_FILE" 2>/dev/null > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "$ENV_FILE" || true
echo "BB_AVAILABLE=true" >> "$ENV_FILE"
echo "BB_DB_PATH=$DB_PATH" >> "$ENV_FILE"
echo "BB_VENV=$VENV_DIR" >> "$ENV_FILE"

echo ""
echo "========================================"
echo " ✅ BrainBank 就绪！"
echo "   索引文档: make -f .harness/Makefile index-docs"
echo "   语义检索: make -f .harness/Makefile search-docs QUERY='<关键词>'"
echo "========================================"
