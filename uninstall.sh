#!/usr/bin/env bash
set -uo pipefail

# ============================================================================
# mac-bootstrap / uninstall.sh
# Stop and remove all LaunchAgent services
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

# Reverse startup order
SERVICES=(
    "com.eddie.centurion"
    "com.eddie.telegram-claude-hero"
    "com.eddie.mini-claude-bot"
    "com.eddie.ollama"
)

echo ""
echo "========================================================================"
echo "  ⚠️  Uninstall Services"
echo "========================================================================"
echo ""
echo "  This will stop and remove the following LaunchAgent services:"
for svc in "${SERVICES[@]}"; do
    echo "    - $svc"
done
echo ""
echo "  Note: project code in ~/Projects/ will NOT be deleted."
echo ""
echo "========================================================================"
echo ""
read -rp "Type 'yes' to continue, anything else to exit: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi
echo ""

# Stop services in reverse startup order
for label in "${SERVICES[@]}"; do
    plist="$LAUNCH_AGENTS_DIR/${label}.plist"

    if launchctl list "$label" &>/dev/null 2>&1; then
        info "Stopping service: $label"
        launchctl unload "$plist" 2>/dev/null || true
        ok "Stopped: $label"
    else
        info "$label is not running"
    fi

    if [[ -f "$plist" ]]; then
        rm "$plist"
        ok "Removed: $plist"
    fi
done

echo ""
echo "========================================================================"
echo -e "  ${GREEN}✅ All services stopped and removed${NC}"
echo ""
echo "  Project code is preserved in ~/Projects/"
echo "  To fully clean up, manually run:"
echo "    rm -rf ~/Projects/mini-claude-bot"
echo "    rm -rf ~/Projects/telegram-claude-hero"
echo "    rm -rf ~/Projects/centurion"
echo "    rm -f ~/.telegram-claude-hero.json"
echo "========================================================================"
echo ""
