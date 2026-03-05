#!/usr/bin/env bash
set -uo pipefail

# ============================================================================
# mac-bootstrap / uninstall.sh
# 停止并移除所有 LaunchAgent 服务
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

SERVICES=(
    "com.eddie.centurion"
    "com.eddie.telegram-claude-hero"
    "com.eddie.mini-claude-bot"
    "com.eddie.ollama"
)

echo ""
echo "========================================================================"
echo "  ⚠️  卸载服务"
echo "========================================================================"
echo ""
echo "  将停止并移除以下 LaunchAgent 服务："
for svc in "${SERVICES[@]}"; do
    echo "    - $svc"
done
echo ""
echo "  注意：不会删除 ~/Projects/ 下的项目代码和数据。"
echo ""
echo "========================================================================"
echo ""
read -rp "输入 yes 继续，其他任何输入将退出: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "已取消。"
    exit 0
fi
echo ""

# 按反向启动顺序停止服务
for label in "${SERVICES[@]}"; do
    plist="$LAUNCH_AGENTS_DIR/${label}.plist"

    if launchctl list "$label" &>/dev/null 2>&1; then
        info "停止服务: $label"
        launchctl unload "$plist" 2>/dev/null || true
        ok "已停止: $label"
    else
        info "$label 未在运行"
    fi

    if [[ -f "$plist" ]]; then
        rm "$plist"
        ok "已移除: $plist"
    fi
done

echo ""
echo "========================================================================"
echo -e "  ${GREEN}✅ 所有服务已停止并移除${NC}"
echo ""
echo "  项目代码保留在 ~/Projects/ 下"
echo "  如需完全清理，手动执行："
echo "    rm -rf ~/Projects/mini-claude-bot"
echo "    rm -rf ~/Projects/telegram-claude-hero"
echo "    rm -rf ~/Projects/centurion"
echo "    rm -f ~/.telegram-claude-hero.json"
echo "========================================================================"
echo ""
