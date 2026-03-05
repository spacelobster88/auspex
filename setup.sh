#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# mac-bootstrap / setup.sh
# Phase 2: 克隆项目 + 构建 + 配置 Secrets + 安装 LaunchAgent + 启动服务
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$HOME"
PROJECTS_DIR="$HOME_DIR/Projects"
LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"

# GitHub org/user
GH_OWNER="spacelobster88"

# 服务列表
SERVICES=(
    "mini-claude-bot"
    "telegram-claude-hero"
    "centurion"
)

# ---------- 颜色 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

# ---------- 免责声明 ----------
echo ""
echo "========================================================================"
echo "  ⚠️  免责声明 / DISCLAIMER"
echo "========================================================================"
echo ""
echo "  本脚本会执行以下操作："
echo "    - 从 GitHub 克隆项目到 ~/Projects/"
echo "    - 创建 Python venv 并安装依赖"
echo "    - 编译 Go 项目"
echo "    - 写入配置文件到 HOME 目录"
echo "    - 安装 LaunchAgent 并启动系统服务"
echo ""
echo "  使用本脚本造成的任何系统损坏、数据丢失、服务中断等问题，"
echo "  由用户自行承担全部责任，与开发者无关。"
echo ""
echo "========================================================================"
echo ""
read -rp "输入 yes 继续，其他任何输入将退出: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "已取消。"
    exit 0
fi
echo ""

# ---------- 前置检查 ----------
step "前置检查"

# GitHub CLI
if ! command -v gh &>/dev/null; then
    err "gh (GitHub CLI) 未安装，请先运行 ./install.sh"
    exit 1
fi
if ! gh auth status &>/dev/null 2>&1; then
    err "GitHub 未登录，请先运行: gh auth login"
    exit 1
fi
ok "GitHub CLI 已登录"

# Claude CLI
if ! command -v claude &>/dev/null; then
    warn "Claude CLI 未安装，centurion 和 mini-claude-bot 的部分功能需要它"
    warn "请稍后运行: npm install -g @anthropic-ai/claude-code && claude login"
else
    ok "Claude CLI: $(claude --version 2>&1 || echo 'installed')"
fi

# Ollama
if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    ok "Ollama 服务正在运行"
else
    warn "Ollama 未运行，尝试启动..."
    if command -v brew &>/dev/null; then
        brew services start ollama 2>/dev/null || true
        sleep 3
        if curl -sf http://localhost:11434/api/tags &>/dev/null; then
            ok "Ollama 已启动"
        else
            warn "Ollama 启动失败，mini-claude-bot 的嵌入功能将不可用"
        fi
    fi
fi

# 创建 Projects 目录
mkdir -p "$PROJECTS_DIR"

# ---------- 克隆项目 ----------
step "克隆项目"

for repo in "${SERVICES[@]}"; do
    repo_dir="$PROJECTS_DIR/$repo"
    if [[ -d "$repo_dir/.git" ]]; then
        info "$repo 已存在，拉取最新代码..."
        (cd "$repo_dir" && git pull --ff-only 2>/dev/null || warn "$repo git pull 失败，可能有本地修改")
    else
        info "克隆 $GH_OWNER/$repo..."
        gh repo clone "$GH_OWNER/$repo" "$repo_dir"
    fi
    ok "$repo ✓"
done

# ---------- 构建项目 ----------
step "构建 mini-claude-bot"

MCB_DIR="$PROJECTS_DIR/mini-claude-bot"
cd "$MCB_DIR"

if [[ ! -d .venv ]]; then
    info "创建 Python venv..."
    python3.13 -m venv .venv 2>/dev/null || python3 -m venv .venv
fi
info "安装依赖..."
.venv/bin/pip install -q -r backend/requirements.txt
ok "mini-claude-bot 构建完成"

# .env 配置
if [[ ! -f .env ]]; then
    cp "$SCRIPT_DIR/env/mini-claude-bot.env.example" .env
    info "已创建 .env 模板，稍后配置"
fi

step "构建 telegram-claude-hero"

TCH_DIR="$PROJECTS_DIR/telegram-claude-hero"
cd "$TCH_DIR"

info "编译 Go 项目..."
go build -o telegram-claude-hero .
ok "telegram-claude-hero 构建完成"

step "构建 centurion"

CENT_DIR="$PROJECTS_DIR/centurion"
cd "$CENT_DIR"

if [[ ! -d .venv ]]; then
    info "创建 Python venv..."
    python3.13 -m venv .venv 2>/dev/null || python3 -m venv .venv
fi
info "安装依赖..."
.venv/bin/pip install -q -e ".[dev]"
ok "centurion 构建完成"

# ---------- Secrets 配置 ----------
step "配置 Secrets"

# Telegram Bot Token
TCH_CONFIG="$HOME_DIR/.telegram-claude-hero.json"
if [[ -f "$TCH_CONFIG" ]]; then
    ok "Telegram 配置已存在: $TCH_CONFIG"
else
    echo ""
    echo "需要 Telegram Bot Token（从 @BotFather 获取）"
    read -rp "输入 Telegram Bot Token (留空跳过): " tg_token
    if [[ -n "$tg_token" ]]; then
        cat > "$TCH_CONFIG" <<EOF
{
  "telegram_bot_token": "$tg_token",
  "gateway_url": "http://localhost:8000"
}
EOF
        chmod 600 "$TCH_CONFIG"
        ok "Telegram 配置已写入: $TCH_CONFIG"
    else
        warn "跳过 Telegram 配置，telegram-claude-hero 将无法启动"
    fi
fi

# mini-claude-bot .env
MCB_ENV="$MCB_DIR/.env"
if grep -q "METRICS_SECRET=$" "$MCB_ENV" 2>/dev/null; then
    echo ""
    echo "可选：配置 Dashboard Metrics Secret（用于推送监控数据到 Vercel）"
    read -rp "输入 METRICS_SECRET (留空跳过): " metrics_secret
    if [[ -n "$metrics_secret" ]]; then
        sed -i '' "s|METRICS_SECRET=|METRICS_SECRET=$metrics_secret|" "$MCB_ENV"
        ok "METRICS_SECRET 已配置"
    else
        info "跳过 METRICS_SECRET"
    fi
fi

# Claude 登录提示
if command -v claude &>/dev/null; then
    if ! claude --version &>/dev/null 2>&1; then
        echo ""
        warn "Claude CLI 尚未登录"
        echo "请在脚本结束后运行: claude login"
    fi
fi

# ---------- 安装 LaunchAgents ----------
step "安装 LaunchAgent 服务"

mkdir -p "$LAUNCH_AGENTS_DIR"

PLIST_TEMPLATES=(
    "com.eddie.ollama"
    "com.eddie.mini-claude-bot"
    "com.eddie.telegram-claude-hero"
    "com.eddie.centurion"
)

for label in "${PLIST_TEMPLATES[@]}"; do
    template="$SCRIPT_DIR/launchd/${label}.plist.template"
    target="$LAUNCH_AGENTS_DIR/${label}.plist"

    if [[ ! -f "$template" ]]; then
        warn "模板不存在: $template"
        continue
    fi

    # 如果服务正在运行，先卸载
    if launchctl list "$label" &>/dev/null 2>&1; then
        info "卸载已有服务: $label"
        launchctl unload "$target" 2>/dev/null || true
    fi

    # 替换模板变量
    sed "s|__HOME__|$HOME_DIR|g" "$template" > "$target"
    ok "已安装: $target"
done

# ---------- 启动服务（按顺序）----------
step "启动服务"

info "启动顺序: Ollama → mini-claude-bot → telegram-claude-hero → centurion"
echo ""

# 1. Ollama
OLLAMA_PLIST="$LAUNCH_AGENTS_DIR/com.eddie.ollama.plist"
if [[ -f "$OLLAMA_PLIST" ]]; then
    launchctl load "$OLLAMA_PLIST" 2>/dev/null || true
    info "等待 Ollama 启动..."
    for i in $(seq 1 10); do
        if curl -sf http://localhost:11434/api/tags &>/dev/null; then
            ok "Ollama 已启动 (port 11434)"
            break
        fi
        sleep 1
    done
fi

# 2. mini-claude-bot
MCB_PLIST="$LAUNCH_AGENTS_DIR/com.eddie.mini-claude-bot.plist"
if [[ -f "$MCB_PLIST" ]]; then
    launchctl load "$MCB_PLIST" 2>/dev/null || true
    info "等待 mini-claude-bot 启动..."
    for i in $(seq 1 10); do
        if curl -sf http://localhost:8000/api/gateway/sessions &>/dev/null; then
            ok "mini-claude-bot 已启动 (port 8000)"
            break
        fi
        sleep 1
    done
fi

# 3. telegram-claude-hero
TCH_PLIST="$LAUNCH_AGENTS_DIR/com.eddie.telegram-claude-hero.plist"
if [[ -f "$TCH_PLIST" ]]; then
    launchctl load "$TCH_PLIST" 2>/dev/null || true
    sleep 2
    if pgrep -f "telegram-claude-hero" &>/dev/null; then
        ok "telegram-claude-hero 已启动"
    else
        warn "telegram-claude-hero 可能未正常启动，检查日志: /tmp/telegram-claude-hero.log"
    fi
fi

# 4. centurion
CENT_PLIST="$LAUNCH_AGENTS_DIR/com.eddie.centurion.plist"
if [[ -f "$CENT_PLIST" ]]; then
    launchctl load "$CENT_PLIST" 2>/dev/null || true
    info "等待 centurion 启动..."
    for i in $(seq 1 10); do
        if curl -sf http://localhost:8100/status &>/dev/null; then
            ok "centurion 已启动 (port 8100)"
            break
        fi
        sleep 1
    done
fi

# ---------- Claude MCP 配置 ----------
step "配置 Claude MCP Server"

CLAUDE_SETTINGS="$HOME_DIR/.claude/settings.json"
if command -v claude &>/dev/null; then
    # 使用 claude mcp add 注册 centurion
    claude mcp add centurion \
        "$CENT_DIR/.venv/bin/python" \
        -e CENTURION_API_BASE=http://localhost:8100/api/centurion \
        -- -m centurion.mcp.tools 2>/dev/null && ok "Centurion MCP server 已注册" || warn "MCP 注册失败，可手动配置"
else
    warn "Claude CLI 未安装，跳过 MCP 配置"
fi

# ---------- 完成 ----------
echo ""
echo "========================================================================"
echo -e "  ${GREEN}✅ Phase 2 完成：项目已部署并启动${NC}"
echo ""
echo "  运行健康检查:  ./health-check.sh"
echo ""
echo "  服务日志:"
echo "    Ollama:              /opt/homebrew/var/log/ollama.log"
echo "    mini-claude-bot:     /tmp/mini-claude-bot.log"
echo "    telegram-claude-hero: /tmp/telegram-claude-hero.log"
echo "    centurion:           /tmp/centurion.log"
echo ""
echo "  手动步骤（如果尚未完成）:"
echo "    - claude login       # Claude CLI 登录"
echo "    - 系统设置 → 隐私 → 给 Terminal 授权 Accessibility/Full Disk Access/Automation"
echo "========================================================================"
echo ""
