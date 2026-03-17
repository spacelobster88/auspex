#!/bin/bash
# restore.sh — Restore stack to a tagged snapshot
#
# Usage: restore.sh <version>
# Example: restore.sh v1.0.0

set -euo pipefail

VERSION="${1:?Usage: restore.sh <version>}"

PROJECTS_DIR="$HOME/Projects"
AUSPEX_DIR="$PROJECTS_DIR/auspex"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[restore]${NC} $*"; }
warn()  { echo -e "${YELLOW}[restore]${NC} $*"; }
error() { echo -e "${RED}[restore]${NC} $*" >&2; }

# Verify the tag exists in auspex
cd "$AUSPEX_DIR"
if ! git rev-parse "$VERSION" >/dev/null 2>&1; then
    error "Tag $VERSION not found in auspex repo."
    error "Available snapshots:"
    git tag -l 'v*' --sort=-version:refname | while read t; do echo "  $t"; done
    exit 1
fi

# Read stack.json from that tag
STACK_AT_TAG=$(git show "$VERSION:stack.json" 2>/dev/null)
if [[ -z "$STACK_AT_TAG" ]]; then
    error "Cannot read stack.json from tag $VERSION"
    exit 1
fi

info "Restoring to snapshot $VERSION..."
echo ""

# Parse services and their refs
SERVICES_DATA=$(echo "$STACK_AT_TAG" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for svc, info in d['services'].items():
    print(f\"{svc} {info['ref']}\")
")

# Check for dirty repos first
DIRTY=()
while IFS=' ' read -r svc ref; do
    repo_dir="$PROJECTS_DIR/$svc"
    [[ ! -d "$repo_dir/.git" ]] && continue
    if [[ -n "$(cd "$repo_dir" && git status --porcelain 2>/dev/null)" ]]; then
        DIRTY+=("$svc")
    fi
done <<< "$SERVICES_DATA"

if [[ ${#DIRTY[@]} -gt 0 ]]; then
    error "Uncommitted changes in: ${DIRTY[*]}"
    error "Stash or commit first."
    exit 1
fi

# Checkout each service to its pinned ref
while IFS=' ' read -r svc ref; do
    repo_dir="$PROJECTS_DIR/$svc"
    if [[ ! -d "$repo_dir/.git" ]]; then
        warn "Skipping $svc (not cloned)"
        continue
    fi

    current=$(cd "$repo_dir" && git rev-parse HEAD)
    if [[ "$current" == "$ref" ]]; then
        info "  $svc: already at ${ref:0:7}"
    else
        (cd "$repo_dir" && git fetch origin "$VERSION" 2>/dev/null || git fetch origin 2>/dev/null || true)
        if (cd "$repo_dir" && git checkout "$VERSION" 2>/dev/null); then
            info "  $svc: checked out tag $VERSION (${ref:0:7})"
        elif (cd "$repo_dir" && git checkout "$ref" 2>/dev/null); then
            info "  $svc: checked out ${ref:0:7}"
        else
            error "  $svc: failed to checkout $ref"
        fi
    fi
done <<< "$SERVICES_DATA"

# Restore auspex's stack.json
cd "$AUSPEX_DIR"
git checkout "$VERSION" -- stack.json 2>/dev/null || true

echo ""
info "=== Restored to $VERSION ==="
info ""
info "NOTE: Services are in detached HEAD state."
info "To return to latest: cd ~/Projects/<service> && git checkout main"
