#!/usr/bin/env bash
set -uo pipefail

# ============================================================================
# mac-bootstrap / health-check.sh
# Phase 3: Verify all services are healthy
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN_COUNT=0

pass() { echo -e "  ${GREEN}✅${NC} $*"; ((PASS++)); }
fail() { echo -e "  ${RED}❌${NC} $*"; ((FAIL++)); }
skip() { echo -e "  ${YELLOW}⚠️${NC}  $*"; ((WARN_COUNT++)); }

echo ""
echo "========================================================================"
echo "  🏥 Service Health Check"
echo "========================================================================"
echo ""

# ---------- System info ----------
echo -e "${BLUE}[System]${NC}"
echo "  Host: $(hostname)"
echo "  macOS: $(sw_vers -productVersion)"
echo "  Chip: $(uname -m)"

TOTAL_MEM_GB="$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1073741824}')"
PHYS_MEM="$(top -l 1 -s 0 2>/dev/null | grep PhysMem || echo 'N/A')"
echo "  RAM: ${TOTAL_MEM_GB}GB — $PHYS_MEM"

AVAIL_DISK_GB="$(df -g / | tail -1 | awk '{print $4}')"
echo "  Disk available: ${AVAIL_DISK_GB}GB"
echo ""

# ---------- Ollama ----------
echo -e "${BLUE}[Ollama]${NC} (port 11434)"
if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    pass "Ollama service running"
    if curl -sf http://localhost:11434/api/tags | grep -q "nomic-embed-text"; then
        pass "nomic-embed-text model available"
    else
        fail "nomic-embed-text model not found"
    fi
else
    fail "Ollama service not responding"
fi
echo ""

# ---------- mini-claude-bot ----------
echo -e "${BLUE}[mini-claude-bot]${NC} (port 8000)"
if curl -sf http://localhost:8000/api/gateway/sessions &>/dev/null; then
    pass "mini-claude-bot service running"
else
    fail "mini-claude-bot service not responding"
fi

if pgrep -f "uvicorn.*backend.main" &>/dev/null; then
    PID=$(pgrep -f "uvicorn.*backend.main" | head -1)
    pass "Process running (PID: $PID)"
else
    fail "uvicorn process not found"
fi
echo ""

# ---------- telegram-claude-hero ----------
echo -e "${BLUE}[telegram-claude-hero]${NC}"
if pgrep -f "telegram-claude-hero" &>/dev/null; then
    PID=$(pgrep -f "telegram-claude-hero" | head -1)
    pass "Process running (PID: $PID)"
else
    fail "telegram-claude-hero process not found"
fi

if [[ -f "$HOME/.telegram-claude-hero.json" ]]; then
    pass "Telegram config file exists"
else
    fail "Missing config file: ~/.telegram-claude-hero.json"
fi
echo ""

# ---------- centurion ----------
echo -e "${BLUE}[centurion]${NC} (port 8100)"
if curl -sf http://localhost:8100/status &>/dev/null; then
    pass "centurion service running"
else
    if pgrep -f "centurion" &>/dev/null; then
        skip "centurion process exists but HTTP not responding"
    else
        fail "centurion service not running"
    fi
fi
echo ""

# ---------- Claude CLI ----------
echo -e "${BLUE}[Claude CLI]${NC}"
if command -v claude &>/dev/null; then
    pass "Claude CLI: $(claude --version 2>&1 || echo 'installed')"
else
    fail "Claude CLI not installed"
fi
echo ""

# ---------- LaunchAgents ----------
echo -e "${BLUE}[LaunchAgents]${NC}"
for label in com.eddie.ollama com.eddie.mini-claude-bot com.eddie.telegram-claude-hero com.eddie.centurion; do
    plist="$HOME/Library/LaunchAgents/${label}.plist"
    if [[ -f "$plist" ]]; then
        if launchctl list "$label" &>/dev/null 2>&1; then
            pass "$label — loaded"
        else
            skip "$label — plist exists but not loaded"
        fi
    else
        fail "$label — plist not found"
    fi
done
echo ""

# ---------- Summary ----------
echo "========================================================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}  ${YELLOW}${WARN_COUNT} warnings${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}🎉 All services healthy!${NC}"
else
    echo -e "  ${YELLOW}Please check the failed items above${NC}"
    echo ""
    echo "  View logs:"
    echo "    tail -50 /opt/homebrew/var/log/ollama.log"
    echo "    tail -50 /tmp/mini-claude-bot.log"
    echo "    tail -50 /tmp/telegram-claude-hero.log"
    echo "    tail -50 /tmp/centurion.log"
fi
echo "========================================================================"
echo ""

exit $FAIL
