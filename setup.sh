#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# mac-bootstrap / setup.sh
# Phase 2: Clone projects + build + configure secrets + install LaunchAgents
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$HOME"
PROJECTS_DIR="$HOME_DIR/Projects"
LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"

# GitHub org/user
GH_OWNER="spacelobster88"

# Service list
SERVICES=(
    "mini-claude-bot"
    "telegram-claude-hero"
    "centurion"
)

# ---------- Colors ----------
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

# ---------- Disclaimer ----------
echo ""
echo "========================================================================"
echo "  ⚠️  DISCLAIMER"
echo "========================================================================"
echo ""
echo "  This script will:"
echo "    - Clone projects from GitHub into ~/Projects/"
echo "    - Create Python venvs and install dependencies"
echo "    - Compile Go projects"
echo "    - Write configuration files to your HOME directory"
echo "    - Install LaunchAgents and start system services"
echo ""
echo "  Any system damage, data loss, or service disruption caused by"
echo "  this script is entirely the user's responsibility."
echo "  The developer assumes no liability whatsoever."
echo ""
echo "========================================================================"
echo ""
read -rp "Type 'yes' to continue, anything else to exit: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi
echo ""

# ---------- Prerequisites ----------
step "Prerequisites"

# GitHub CLI
if ! command -v gh &>/dev/null; then
    err "gh (GitHub CLI) not installed — run ./install.sh first"
    exit 1
fi
if ! gh auth status &>/dev/null 2>&1; then
    err "GitHub not logged in — run: gh auth login"
    exit 1
fi
ok "GitHub CLI authenticated"

# Claude CLI
if ! command -v claude &>/dev/null; then
    warn "Claude CLI not installed — some features of centurion and mini-claude-bot require it"
    warn "Install later with: npm install -g @anthropic-ai/claude-code && claude login"
else
    ok "Claude CLI: $(claude --version 2>&1 || echo 'installed')"
fi

# Ollama
if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    ok "Ollama service running"
else
    warn "Ollama not running, attempting to start..."
    if command -v brew &>/dev/null; then
        brew services start ollama 2>/dev/null || true
        sleep 3
        if curl -sf http://localhost:11434/api/tags &>/dev/null; then
            ok "Ollama started"
        else
            warn "Ollama failed to start — mini-claude-bot embeddings will be unavailable"
        fi
    fi
fi

# Create Projects directory
mkdir -p "$PROJECTS_DIR"

# ---------- Clone projects ----------
step "Cloning projects"

for repo in "${SERVICES[@]}"; do
    repo_dir="$PROJECTS_DIR/$repo"
    if [[ -d "$repo_dir/.git" ]]; then
        info "$repo already exists, pulling latest..."
        (cd "$repo_dir" && git pull --ff-only 2>/dev/null || warn "$repo git pull failed — may have local changes")
    else
        info "Cloning $GH_OWNER/$repo..."
        gh repo clone "$GH_OWNER/$repo" "$repo_dir"
    fi
    ok "$repo ✓"
done

# ---------- Build projects ----------
step "Building mini-claude-bot"

MCB_DIR="$PROJECTS_DIR/mini-claude-bot"
cd "$MCB_DIR"

if [[ ! -d .venv ]]; then
    info "Creating Python venv..."
    python3.13 -m venv .venv 2>/dev/null || python3 -m venv .venv
fi
info "Installing dependencies..."
.venv/bin/pip install -q -r backend/requirements.txt
ok "mini-claude-bot build complete"

# .env config
if [[ ! -f .env ]]; then
    cp "$SCRIPT_DIR/env/mini-claude-bot.env.example" .env
    info "Created .env template — will configure shortly"
fi

step "Building telegram-claude-hero"

TCH_DIR="$PROJECTS_DIR/telegram-claude-hero"
cd "$TCH_DIR"

info "Compiling Go project..."
go build -o telegram-claude-hero .
ok "telegram-claude-hero build complete"

step "Building centurion"

CENT_DIR="$PROJECTS_DIR/centurion"
cd "$CENT_DIR"

if [[ ! -d .venv ]]; then
    info "Creating Python venv..."
    python3.13 -m venv .venv 2>/dev/null || python3 -m venv .venv
fi
info "Installing dependencies..."
.venv/bin/pip install -q -e ".[dev]"
ok "centurion build complete"

# ---------- Secrets configuration ----------
step "Configuring secrets"

# Telegram Bot Token
TCH_CONFIG="$HOME_DIR/.telegram-claude-hero.json"
if [[ -f "$TCH_CONFIG" ]]; then
    ok "Telegram config already exists: $TCH_CONFIG"
else
    echo ""
    echo "Telegram Bot Token is required (get it from @BotFather)"
    read -rp "Enter Telegram Bot Token (leave empty to skip): " tg_token
    if [[ -n "$tg_token" ]]; then
        cat > "$TCH_CONFIG" <<EOF
{
  "telegram_bot_token": "$tg_token",
  "gateway_url": "http://localhost:8000"
}
EOF
        chmod 600 "$TCH_CONFIG"
        ok "Telegram config written: $TCH_CONFIG"
    else
        warn "Skipped Telegram config — telegram-claude-hero will not be able to start"
    fi
fi

# mini-claude-bot .env
MCB_ENV="$MCB_DIR/.env"
if grep -q "METRICS_SECRET=$" "$MCB_ENV" 2>/dev/null; then
    echo ""
    echo "Optional: Dashboard Metrics Secret (for pushing metrics to Vercel)"
    read -rp "Enter METRICS_SECRET (leave empty to skip): " metrics_secret
    if [[ -n "$metrics_secret" ]]; then
        sed -i '' "s|METRICS_SECRET=|METRICS_SECRET=$metrics_secret|" "$MCB_ENV"
        ok "METRICS_SECRET configured"
    else
        info "Skipped METRICS_SECRET"
    fi
fi

# Claude login reminder
if command -v claude &>/dev/null; then
    if ! claude --version &>/dev/null 2>&1; then
        echo ""
        warn "Claude CLI is not logged in"
        echo "Run after this script finishes: claude login"
    fi
fi

# ---------- Install LaunchAgents ----------
step "Installing LaunchAgent services"

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
        warn "Template not found: $template"
        continue
    fi

    # Unload if already running
    if launchctl list "$label" &>/dev/null 2>&1; then
        info "Unloading existing service: $label"
        launchctl unload "$target" 2>/dev/null || true
    fi

    # Replace template variables
    sed "s|__HOME__|$HOME_DIR|g" "$template" > "$target"
    ok "Installed: $target"
done

# ---------- Start services (in order) ----------
step "Starting services"

info "Start order: Ollama → mini-claude-bot → telegram-claude-hero → centurion"
echo ""

# 1. Ollama
OLLAMA_PLIST="$LAUNCH_AGENTS_DIR/com.eddie.ollama.plist"
if [[ -f "$OLLAMA_PLIST" ]]; then
    launchctl load "$OLLAMA_PLIST" 2>/dev/null || true
    info "Waiting for Ollama to start..."
    for i in $(seq 1 10); do
        if curl -sf http://localhost:11434/api/tags &>/dev/null; then
            ok "Ollama started (port 11434)"
            break
        fi
        sleep 1
    done
fi

# 2. mini-claude-bot
MCB_PLIST="$LAUNCH_AGENTS_DIR/com.eddie.mini-claude-bot.plist"
if [[ -f "$MCB_PLIST" ]]; then
    launchctl load "$MCB_PLIST" 2>/dev/null || true
    info "Waiting for mini-claude-bot to start..."
    for i in $(seq 1 10); do
        if curl -sf http://localhost:8000/api/gateway/sessions &>/dev/null; then
            ok "mini-claude-bot started (port 8000)"
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
        ok "telegram-claude-hero started"
    else
        warn "telegram-claude-hero may not have started — check log: /tmp/telegram-claude-hero.log"
    fi
fi

# 4. centurion
CENT_PLIST="$LAUNCH_AGENTS_DIR/com.eddie.centurion.plist"
if [[ -f "$CENT_PLIST" ]]; then
    launchctl load "$CENT_PLIST" 2>/dev/null || true
    info "Waiting for centurion to start..."
    for i in $(seq 1 10); do
        if curl -sf http://localhost:8100/status &>/dev/null; then
            ok "centurion started (port 8100)"
            break
        fi
        sleep 1
    done
fi

# ---------- Claude MCP configuration ----------
step "Configuring Claude MCP Server"

if command -v claude &>/dev/null; then
    claude mcp add centurion \
        "$CENT_DIR/.venv/bin/python" \
        -e CENTURION_API_BASE=http://localhost:8100/api/centurion \
        -- -m centurion.mcp.tools 2>/dev/null && ok "Centurion MCP server registered" || warn "MCP registration failed — configure manually if needed"
else
    warn "Claude CLI not installed — skipping MCP configuration"
fi

# ---------- Done ----------
echo ""
echo "========================================================================"
echo -e "  ${GREEN}✅ Phase 2 complete: projects deployed and services started${NC}"
echo ""
echo "  Run health check:  ./health-check.sh"
echo ""
echo "  Service logs:"
echo "    Ollama:               /opt/homebrew/var/log/ollama.log"
echo "    mini-claude-bot:      /tmp/mini-claude-bot.log"
echo "    telegram-claude-hero: /tmp/telegram-claude-hero.log"
echo "    centurion:            /tmp/centurion.log"
echo ""
echo "  Manual steps (if not done yet):"
echo "    - claude login       # Claude CLI login"
echo "    - System Settings → Privacy → grant Terminal Accessibility/Full Disk Access/Automation"
echo "========================================================================"
echo ""
