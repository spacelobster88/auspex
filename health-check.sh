#!/usr/bin/env bash
set -uo pipefail

# ============================================================================
# mac-bootstrap / health-check.sh
# Phase 3: 验证所有服务健康状态
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
echo "  🏥 服务健康检查"
echo "========================================================================"
echo ""

# ---------- 系统信息 ----------
echo -e "${BLUE}[系统]${NC}"
echo "  主机: $(hostname)"
echo "  macOS: $(sw_vers -productVersion)"
echo "  芯片: $(uname -m)"

TOTAL_MEM_GB="$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1073741824}')"
PHYS_MEM="$(top -l 1 -s 0 2>/dev/null | grep PhysMem || echo 'N/A')"
echo "  内存: ${TOTAL_MEM_GB}GB — $PHYS_MEM"

AVAIL_DISK_GB="$(df -g / | tail -1 | awk '{print $4}')"
echo "  磁盘可用: ${AVAIL_DISK_GB}GB"
echo ""

# ---------- Ollama ----------
echo -e "${BLUE}[Ollama]${NC} (port 11434)"
if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    pass "Ollama 服务运行中"
    if curl -sf http://localhost:11434/api/tags | grep -q "nomic-embed-text"; then
        pass "nomic-embed-text 模型可用"
    else
        fail "nomic-embed-text 模型未找到"
    fi
else
    fail "Ollama 服务未响应"
fi
echo ""

# ---------- mini-claude-bot ----------
echo -e "${BLUE}[mini-claude-bot]${NC} (port 8000)"
if curl -sf http://localhost:8000/api/gateway/sessions &>/dev/null; then
    pass "mini-claude-bot 服务运行中"
else
    fail "mini-claude-bot 服务未响应"
fi

if pgrep -f "uvicorn.*backend.main" &>/dev/null; then
    PID=$(pgrep -f "uvicorn.*backend.main" | head -1)
    pass "进程运行中 (PID: $PID)"
else
    fail "uvicorn 进程未找到"
fi
echo ""

# ---------- telegram-claude-hero ----------
echo -e "${BLUE}[telegram-claude-hero]${NC}"
if pgrep -f "telegram-claude-hero" &>/dev/null; then
    PID=$(pgrep -f "telegram-claude-hero" | head -1)
    pass "进程运行中 (PID: $PID)"
else
    fail "telegram-claude-hero 进程未找到"
fi

if [[ -f "$HOME/.telegram-claude-hero.json" ]]; then
    pass "Telegram 配置文件存在"
else
    fail "缺少配置文件: ~/.telegram-claude-hero.json"
fi
echo ""

# ---------- centurion ----------
echo -e "${BLUE}[centurion]${NC} (port 8100)"
if curl -sf http://localhost:8100/status &>/dev/null; then
    pass "centurion 服务运行中"
else
    if pgrep -f "centurion" &>/dev/null; then
        skip "centurion 进程存在但 HTTP 未响应"
    else
        fail "centurion 服务未运行"
    fi
fi
echo ""

# ---------- Claude CLI ----------
echo -e "${BLUE}[Claude CLI]${NC}"
if command -v claude &>/dev/null; then
    pass "Claude CLI: $(claude --version 2>&1 || echo 'installed')"
else
    fail "Claude CLI 未安装"
fi
echo ""

# ---------- LaunchAgents ----------
echo -e "${BLUE}[LaunchAgents]${NC}"
for label in com.eddie.ollama com.eddie.mini-claude-bot com.eddie.telegram-claude-hero com.eddie.centurion; do
    plist="$HOME/Library/LaunchAgents/${label}.plist"
    if [[ -f "$plist" ]]; then
        if launchctl list "$label" &>/dev/null 2>&1; then
            pass "$label — 已加载"
        else
            skip "$label — plist 存在但未加载"
        fi
    else
        fail "$label — plist 不存在"
    fi
done
echo ""

# ---------- 汇总 ----------
echo "========================================================================"
echo -e "  结果: ${GREEN}${PASS} 通过${NC}  ${RED}${FAIL} 失败${NC}  ${YELLOW}${WARN_COUNT} 警告${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}🎉 所有服务正常！${NC}"
else
    echo -e "  ${YELLOW}请检查上述失败项${NC}"
    echo ""
    echo "  查看日志:"
    echo "    tail -50 /opt/homebrew/var/log/ollama.log"
    echo "    tail -50 /tmp/mini-claude-bot.log"
    echo "    tail -50 /tmp/telegram-claude-hero.log"
    echo "    tail -50 /tmp/centurion.log"
fi
echo "========================================================================"
echo ""

exit $FAIL
