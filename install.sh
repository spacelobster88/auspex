#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# mac-bootstrap / install.sh
# Phase 1: 安装系统级依赖
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- 颜色 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- 免责声明 ----------
echo ""
echo "========================================================================"
echo "  ⚠️  免责声明 / DISCLAIMER"
echo "========================================================================"
echo ""
echo "  本脚本会在你的系统上安装以下软件："
echo "    - Xcode Command Line Tools"
echo "    - Homebrew"
echo "    - Python 3.13, Go, Node.js, Ollama, GitHub CLI, Tectonic (LaTeX)"
echo "    - Claude CLI (via npm)"
echo "    - Ollama nomic-embed-text 模型"
echo ""
echo "  使用本脚本造成的任何系统损坏、数据丢失、服务中断等问题，"
echo "  由用户自行承担全部责任，与开发者无关。"
echo ""
echo "  请在运行前仔细阅读脚本内容，确认你理解每一步操作。"
echo ""
echo "========================================================================"
echo ""
read -rp "输入 yes 继续，其他任何输入将退出: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "已取消。"
    exit 0
fi
echo ""

# ---------- 硬件检测 ----------
info "检查硬件环境..."

# 芯片架构
ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
    err "需要 Apple Silicon (arm64)，当前架构: $ARCH"
    exit 1
fi
ok "芯片: Apple Silicon ($ARCH)"

# macOS 版本
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="$(echo "$MACOS_VERSION" | cut -d. -f1)"
if [[ "$MACOS_MAJOR" -lt 14 ]]; then
    err "需要 macOS 14 (Sonoma) 或更高版本，当前: $MACOS_VERSION"
    exit 1
fi
ok "macOS: $MACOS_VERSION"

# 内存
TOTAL_MEM_GB="$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1073741824}')"
if [[ "$TOTAL_MEM_GB" -lt 16 ]]; then
    warn "内存 ${TOTAL_MEM_GB}GB，推荐 16GB+（Claude CLI 峰值可达 6-10GB）"
else
    ok "内存: ${TOTAL_MEM_GB}GB"
fi

# 磁盘
AVAIL_DISK_GB="$(df -g / | tail -1 | awk '{print $4}')"
if [[ "$AVAIL_DISK_GB" -lt 30 ]]; then
    err "可用磁盘空间 ${AVAIL_DISK_GB}GB，至少需要 30GB"
    exit 1
fi
ok "可用磁盘: ${AVAIL_DISK_GB}GB"

echo ""

# ---------- Xcode Command Line Tools ----------
info "检查 Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
    ok "Xcode CLT 已安装"
else
    info "安装 Xcode Command Line Tools..."
    xcode-select --install
    echo ""
    warn "请在弹出的对话框中点击「安装」，安装完成后重新运行本脚本。"
    exit 0
fi

# ---------- Homebrew ----------
info "检查 Homebrew..."
if command -v brew &>/dev/null; then
    ok "Homebrew 已安装: $(brew --version | head -1)"
    info "更新 Homebrew..."
    brew update --quiet
else
    info "安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # 确保 brew 在 PATH 中
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Homebrew 安装完成"
fi

# ---------- Brewfile ----------
info "通过 Brewfile 安装依赖..."
brew bundle --file="$SCRIPT_DIR/Brewfile" --quiet
ok "Brewfile 依赖安装完成"

# 验证关键工具
for cmd in python3.13 go node ollama gh tectonic; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd: $(command -v "$cmd")"
    else
        # python3.13 可能叫 python3
        if [[ "$cmd" == "python3.13" ]] && command -v python3 &>/dev/null; then
            PY_VER="$(python3 --version 2>&1)"
            if [[ "$PY_VER" == *"3.13"* ]] || [[ "$PY_VER" == *"3.14"* ]]; then
                ok "python3: $PY_VER"
                continue
            fi
        fi
        warn "$cmd 未找到，可能需要重新打开终端或手动安装"
    fi
done

# ---------- Claude CLI ----------
info "检查 Claude CLI..."
if command -v claude &>/dev/null; then
    ok "Claude CLI: $(claude --version 2>&1 || echo 'installed')"
else
    info "安装 Claude CLI..."
    npm install -g @anthropic-ai/claude-code
    if command -v claude &>/dev/null; then
        ok "Claude CLI 安装完成"
    else
        warn "Claude CLI 安装完成，可能需要重新打开终端"
    fi
fi

# ---------- Ollama 模型 ----------
info "检查 Ollama nomic-embed-text 模型..."

# 确保 Ollama 服务在运行
if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
    info "启动 Ollama 服务..."
    brew services start ollama
    sleep 3
fi

if ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
    ok "nomic-embed-text 模型已存在"
else
    info "拉取 nomic-embed-text 模型..."
    ollama pull nomic-embed-text
    ok "nomic-embed-text 模型拉取完成"
fi

# ---------- 完成 ----------
echo ""
echo "========================================================================"
echo -e "  ${GREEN}✅ Phase 1 完成：系统依赖已安装${NC}"
echo ""
echo "  下一步："
echo "    1. 如果尚未登录 GitHub:  gh auth login"
echo "    2. 如果尚未登录 Claude:  claude login"
echo "    3. 运行 Phase 2:         ./setup.sh"
echo "========================================================================"
echo ""
