#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# mac-bootstrap / install.sh
# Phase 1: Install system-level dependencies
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- Disclaimer ----------
echo ""
echo "========================================================================"
echo "  ⚠️  DISCLAIMER"
echo "========================================================================"
echo ""
echo "  This script will install the following on your system:"
echo "    - Xcode Command Line Tools"
echo "    - Homebrew"
echo "    - Python 3.13, Go, Node.js, Ollama, GitHub CLI, Tectonic (LaTeX)"
echo "    - Claude CLI (via npm)"
echo "    - Ollama nomic-embed-text model"
echo ""
echo "  Any system damage, data loss, or service disruption caused by"
echo "  this script is entirely the user's responsibility."
echo "  The developer assumes no liability whatsoever."
echo ""
echo "  Please read the script contents carefully before proceeding."
echo ""
echo "========================================================================"
echo ""
read -rp "Type 'yes' to continue, anything else to exit: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi
echo ""

# ---------- Hardware checks ----------
info "Checking hardware environment..."

# CPU architecture
ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
    err "Apple Silicon (arm64) required, current architecture: $ARCH"
    exit 1
fi
ok "Chip: Apple Silicon ($ARCH)"

# macOS version
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="$(echo "$MACOS_VERSION" | cut -d. -f1)"
if [[ "$MACOS_MAJOR" -lt 14 ]]; then
    err "macOS 14 (Sonoma) or later required, current: $MACOS_VERSION"
    exit 1
fi
ok "macOS: $MACOS_VERSION"

# Memory
TOTAL_MEM_GB="$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1073741824}')"
if [[ "$TOTAL_MEM_GB" -lt 16 ]]; then
    warn "RAM ${TOTAL_MEM_GB}GB — 16GB+ recommended (Claude CLI peaks at 6-10GB)"
else
    ok "RAM: ${TOTAL_MEM_GB}GB"
fi

# Disk
AVAIL_DISK_GB="$(df -g / | tail -1 | awk '{print $4}')"
if [[ "$AVAIL_DISK_GB" -lt 30 ]]; then
    err "Available disk space ${AVAIL_DISK_GB}GB — at least 30GB required"
    exit 1
fi
ok "Available disk: ${AVAIL_DISK_GB}GB"

echo ""

# ---------- Xcode Command Line Tools ----------
info "Checking Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
    ok "Xcode CLT installed"
else
    info "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo ""
    warn "Please click 'Install' in the dialog that appeared."
    warn "Re-run this script after installation completes."
    exit 0
fi

# ---------- Homebrew ----------
info "Checking Homebrew..."
if command -v brew &>/dev/null; then
    ok "Homebrew installed: $(brew --version | head -1)"
    info "Updating Homebrew..."
    brew update --quiet
else
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Homebrew installed"
fi

# ---------- Brewfile ----------
info "Installing dependencies from Brewfile..."
brew bundle --file="$SCRIPT_DIR/Brewfile" --quiet
ok "Brewfile dependencies installed"

# Verify key tools
for cmd in python3.13 go node ollama gh tectonic; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd: $(command -v "$cmd")"
    else
        if [[ "$cmd" == "python3.13" ]] && command -v python3 &>/dev/null; then
            PY_VER="$(python3 --version 2>&1)"
            if [[ "$PY_VER" == *"3.13"* ]] || [[ "$PY_VER" == *"3.14"* ]]; then
                ok "python3: $PY_VER"
                continue
            fi
        fi
        warn "$cmd not found — you may need to restart your terminal or install manually"
    fi
done

# ---------- Claude CLI ----------
info "Checking Claude CLI..."
if command -v claude &>/dev/null; then
    ok "Claude CLI: $(claude --version 2>&1 || echo 'installed')"
else
    info "Installing Claude CLI..."
    npm install -g @anthropic-ai/claude-code
    if command -v claude &>/dev/null; then
        ok "Claude CLI installed"
    else
        warn "Claude CLI installed — you may need to restart your terminal"
    fi
fi

# ---------- Ollama model ----------
info "Checking Ollama nomic-embed-text model..."

# Ensure Ollama is running
if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
    info "Starting Ollama service..."
    brew services start ollama
    sleep 3
fi

if ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
    ok "nomic-embed-text model available"
else
    info "Pulling nomic-embed-text model..."
    ollama pull nomic-embed-text
    ok "nomic-embed-text model pulled"
fi

# ---------- Done ----------
echo ""
echo "========================================================================"
echo -e "  ${GREEN}✅ Phase 1 complete: system dependencies installed${NC}"
echo ""
echo "  Next steps:"
echo "    1. If not logged into GitHub:  gh auth login"
echo "    2. If not logged into Claude:  claude login"
echo "    3. Run Phase 2:                ./setup.sh"
echo "========================================================================"
echo ""
