#!/bin/bash
# list.sh — List all stack snapshots
set -euo pipefail

AUSPEX_DIR="$HOME/Projects/auspex"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "$AUSPEX_DIR"

echo ""
echo -e "${GREEN}=== Stack Snapshots ===${NC}"
echo ""

TAGS=$(git tag -l 'v*' --sort=-version:refname 2>/dev/null || true)

if [[ -z "$TAGS" ]]; then
    echo "No snapshots found. Create one with: /snapshot"
    exit 0
fi

for tag in $TAGS; do
    date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
    msg=$(git tag -l --format='%(contents:subject)' "$tag" 2>/dev/null)
    echo -e "  ${CYAN}$tag${NC}  ($date)  $msg"

    stack_at_tag=$(git show "$tag:stack.json" 2>/dev/null || true)
    if [[ -n "$stack_at_tag" ]]; then
        echo "$stack_at_tag" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for svc, info in d.get('services', {}).items():
        ref = info.get('ref', '?')[:7]
        tag_name = info.get('tag', '')
        print(f'    {svc}: {ref}')
except:
    pass
" 2>/dev/null || true
    fi
    echo ""
done
