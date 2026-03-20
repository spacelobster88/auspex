#!/bin/bash
# snapshot.sh — Tag all stack services and update stack.json
#
# Usage: snapshot.sh <version> [description]
#   version:     Semver tag, e.g. v1.0.0
#   description: Optional one-line release note
#
# Example:
#   snapshot.sh v1.0.0 "First stable release"

set -euo pipefail

VERSION="${1:?Usage: snapshot.sh <version> [description]}"
DESCRIPTION="${2:-Stack snapshot $VERSION}"

PROJECTS_DIR="$HOME/Projects"
AUSPEX_DIR="$PROJECTS_DIR/auspex"
STACK_FILE="$AUSPEX_DIR/stack.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[snapshot]${NC} $*"; }
warn()  { echo -e "${YELLOW}[snapshot]${NC} $*"; }
error() { echo -e "${RED}[snapshot]${NC} $*" >&2; }

# Validate version format
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-][a-zA-Z0-9._-]+)?$ ]]; then
    error "Version must be semver format: v{major}.{minor}.{patch}[-prerelease]"
    exit 1
fi

# Read service list from stack.json
SERVICES=$(python3 -c "
import json
with open('$STACK_FILE') as f:
    d = json.load(f)
for svc in d['services']:
    print(svc)
")

# Phase 1: Pre-flight checks
info "Pre-flight checks for $VERSION..."
DIRTY_REPOS=()
for svc in $SERVICES; do
    repo_dir="$PROJECTS_DIR/$svc"
    if [[ ! -d "$repo_dir/.git" ]]; then
        warn "Skipping $svc (not cloned at $repo_dir)"
        continue
    fi
    if [[ -n "$(cd "$repo_dir" && git status --porcelain 2>/dev/null)" ]]; then
        DIRTY_REPOS+=("$svc")
    fi
    # Check if tag already exists
    if (cd "$repo_dir" && git rev-parse "$VERSION" >/dev/null 2>&1); then
        error "Tag $VERSION already exists in $svc. Aborting."
        exit 1
    fi
done

if [[ ${#DIRTY_REPOS[@]} -gt 0 ]]; then
    error "Uncommitted changes in: ${DIRTY_REPOS[*]}"
    error "Commit or stash changes first."
    exit 1
fi

# Phase 2: Tag each service
info "Tagging services with $VERSION..."
TAG_RESULTS=()
for svc in $SERVICES; do
    repo_dir="$PROJECTS_DIR/$svc"
    if [[ ! -d "$repo_dir/.git" ]]; then
        continue
    fi
    sha=$(cd "$repo_dir" && git rev-parse HEAD)
    short_sha=${sha:0:7}

    (cd "$repo_dir" && git tag -a "$VERSION" -m "$DESCRIPTION")
    (cd "$repo_dir" && git push origin "$VERSION" 2>&1) || {
        warn "Failed to push tag for $svc — continuing"
    }

    TAG_RESULTS+=("$svc: $short_sha")
    info "  $svc → $short_sha"
done

# Phase 3: Update stack.json
info "Updating stack.json..."
STACK_VERSION="${VERSION#v}"  # strip leading v
python3 -c "
import json, subprocess, os

stack_file = '$STACK_FILE'
version = '$VERSION'
stack_ver = '$STACK_VERSION'
projects = '$PROJECTS_DIR'

with open(stack_file) as f:
    d = json.load(f)

d['stack_version'] = stack_ver
d['released'] = '$(date +%Y-%m-%d)'

for svc, info in d['services'].items():
    repo_dir = os.path.join(projects, svc)
    if os.path.isdir(os.path.join(repo_dir, '.git')):
        sha = subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], cwd=repo_dir
        ).decode().strip()
        info['ref'] = sha
        info['ref_type'] = 'tag'
        info['tag'] = version
        info['version'] = stack_ver

with open(stack_file, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"

# Phase 4: Capture environment variables (sanitized)
info "Capturing environment config..."
SNAP_DIR="$AUSPEX_DIR/snapshots/$VERSION"
mkdir -p "$SNAP_DIR/env"

export VERSION SNAP_DIR
python3 << 'PYEOF'
import os, re, json, glob

version = os.environ["VERSION"]
projects = os.path.expanduser("~/Projects")
auspex = os.path.join(projects, "auspex")
snap_dir = os.path.join(auspex, "snapshots", version, "env")
stack_file = os.path.join(auspex, "stack.json")

# Patterns that indicate sensitive values — NEVER include these
SENSITIVE_PATTERNS = re.compile(
    r'(TOKEN|SECRET|PASSWORD|PASSWD|KEY|CREDENTIAL|AUTH|APIKEY|API_KEY'
    r'|PRIVATE|SIGNING|JWT|BEARER|SESSION|COOKIE|ENCRYPTION'
    r'|BOT_TOKEN|ACCESS_TOKEN|REFRESH_TOKEN'
    r'|SMTP_PASS|DB_PASS|MONGO_URI|DATABASE_URL'
    r')',
    re.IGNORECASE
)

# Patterns that indicate PII — NEVER include these
PII_PATTERNS = re.compile(
    r'(EMAIL|PHONE|SSN|DOB|BIRTH|ADDRESS|CHAT_ID'
    r'|FIRST_NAME|LAST_NAME|FULL_NAME'
    r')',
    re.IGNORECASE
)

# Keys that are safe tuning/config params — always include value
SAFE_PREFIXES = (
    'OLLAMA_', 'DATABASE_PATH', 'LOG_', 'DEBUG', 'PORT', 'HOST',
    'MAX_', 'MIN_', 'TIMEOUT', 'RETRY', 'BATCH', 'CACHE',
    'GATEWAY_MAX', 'GATEWAY_MIN', 'GATEWAY_URL', 'GATEWAY_PORT',
    'WORKERS', 'THREADS', 'CONCURRENCY', 'RATE_LIMIT',
    'DASHBOARD_PUSH_URL', 'REPORT_',
)

def is_sensitive(key):
    """Return True if key likely holds a secret or PII."""
    if SENSITIVE_PATTERNS.search(key):
        return True
    if PII_PATTERNS.search(key):
        return True
    return False

def sanitize_env(filepath):
    """Read .env file, return sanitized lines."""
    lines = []
    if not os.path.isfile(filepath):
        return lines
    with open(filepath) as f:
        for raw in f:
            line = raw.strip()
            # Preserve comments and blank lines
            if not line or line.startswith('#'):
                lines.append(line)
                continue
            # Parse KEY=VALUE
            if '=' not in line:
                continue
            key, _, value = line.partition('=')
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if is_sensitive(key):
                # Redact entirely — don't even hint at the value
                lines.append(f"{key}=REDACTED")
            else:
                lines.append(f"{key}={value}")
    return lines

# Read services from stack.json
with open(stack_file) as f:
    stack = json.load(f)

collected = {}
for svc in stack['services']:
    env_file = os.path.join(projects, svc, ".env")
    sanitized = sanitize_env(env_file)
    if sanitized:
        out_path = os.path.join(snap_dir, f"{svc}.env")
        with open(out_path, 'w') as f:
            f.write('\n'.join(sanitized) + '\n')
        collected[svc] = len([l for l in sanitized if l and not l.startswith('#')])
        print(f"  {svc}: {collected[svc]} vars captured")

# Also capture launchd plist env vars
plist_dir = os.path.join(auspex, "launchd")
plist_env = {}
for plist in glob.glob(os.path.join(plist_dir, "*.plist.template")):
    name = os.path.basename(plist)
    with open(plist) as f:
        content = f.read()
    # Extract EnvironmentVariables keys (simple regex for plist XML)
    env_keys = re.findall(r'<key>(\w+)</key>', content)
    env_vals = re.findall(r'<string>(.*?)</string>', content)
    pairs = list(zip(env_keys, env_vals))
    sanitized_pairs = []
    for k, v in pairs:
        if is_sensitive(k):
            sanitized_pairs.append(f"{k}=REDACTED")
        else:
            sanitized_pairs.append(f"{k}={v}")
    if sanitized_pairs:
        plist_env[name] = sanitized_pairs

if plist_env:
    out_path = os.path.join(snap_dir, "launchd-env.txt")
    with open(out_path, 'w') as f:
        for name, pairs in plist_env.items():
            f.write(f"# {name}\n")
            for p in pairs:
                f.write(p + '\n')
            f.write('\n')
    print(f"  launchd: {sum(len(v) for v in plist_env.values())} vars from {len(plist_env)} plists")

# Write manifest
from datetime import date
manifest = {
    "version": version,
    "date": date.today().isoformat(),
    "services_env_captured": list(collected.keys()),
    "note": "Sensitive values (tokens, passwords, PII) are REDACTED. Only tuning/config params have real values."
}
with open(os.path.join(snap_dir, "..", "manifest.json"), 'w') as f:
    json.dump(manifest, f, indent=2)
    f.write('\n')

PYEOF

info "Environment config saved to snapshots/$VERSION/env/"

# Phase 5: Commit and tag auspex
info "Committing auspex..."
cd "$AUSPEX_DIR"
git add stack.json "snapshots/$VERSION/"
git commit -m "Snapshot $VERSION — $DESCRIPTION" || true
git tag -a "$VERSION" -m "$DESCRIPTION"
git push origin main "$VERSION" 2>&1 || warn "Failed to push auspex — check remote"

# Summary
echo ""
info "=== Snapshot $VERSION complete ==="
info "Description: $DESCRIPTION"
info "Date: $(date +%Y-%m-%d)"
for r in "${TAG_RESULTS[@]}"; do
    info "  $r"
done
echo ""
info "To restore this snapshot later:"
info "  /snapshot restore $VERSION"
