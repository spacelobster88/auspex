# Auspex

**Bootstrap a fresh Mac into a fully operational AI agent hub.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Latest: v1.1.1-auto-restart](https://img.shields.io/badge/Latest-v1.1.1--auto--restart-brightgreen.svg)](https://github.com/spacelobster88/auspex/releases/tag/v1.1.1-auto-restart)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)]()
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2B-black.svg)]()
[![Services](https://img.shields.io/badge/Services-5-orange.svg)]()
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Opus%204.6-blueviolet.svg)]()

> *Before Rome's legions marched, the auspex read the signs and declared the ground fit for action. Auspex does the same for your Mac: it reads the machine, installs every dependency, and prepares the ground so your AI services can march in formation from the first command.*

Three phases. One script per phase. Zero-to-running in under an hour.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                      Your Mac                       │
│                                                     │
│  Ollama (11434)           <- Vector embeddings      │
│    └─> mini-claude-bot (8000)  <- Claude gateway    │
│          └─> telegram-claude-hero  <- Telegram bot  │
│                                                     │
│  Centurion (8100)         <- Agent fleet manager    │
│  Harness Loop (.harness/) <- Project orchestrator   │
└─────────────────────────────────────────────────────┘
```

| Service | Stack | Port | Role |
|---------|-------|------|------|
| [Ollama](https://ollama.com/) | Homebrew | 11434 | Local embeddings (nomic-embed-text) |
| [mini-claude-bot](https://github.com/spacelobster88/mini-claude-bot) | Python 3.13 / FastAPI | 8000 | Multi-session Claude gateway, cron, semantic memory |
| [telegram-claude-hero](https://github.com/spacelobster88/telegram-claude-hero) | Go 1.25 | - | Telegram bridge to mini-claude-bot |
| [centurion](https://github.com/spacelobster88/centurion) | Python 3.12+ / FastAPI | 8100 | AI agent fleet orchestration engine |
| [harness-loop](https://github.com/spacelobster88/harness-loop) | Node.js | - | Iterative project development orchestrator |

---

## Requirements

| | Minimum | Recommended |
|--|---------|-------------|
| Chip | Apple Silicon (M1+) | M2 / M4 |
| RAM | 16 GB | 32 GB+ |
| Disk | 30 GB free | 100 GB+ |
| macOS | 14.0 (Sonoma)+ | Latest |

---

## Quick Start

### Phase 0 -- Prerequisites

1. Grant Terminal/iTerm2: **Accessibility**, **Full Disk Access**, **Automation** (System Settings > Privacy & Security)
2. Have ready: GitHub account, Telegram Bot Token ([@BotFather](https://t.me/BotFather)), Anthropic account

### Phase 1 -- Install Dependencies

```bash
git clone https://github.com/spacelobster88/auspex.git
cd auspex && chmod +x *.sh
./install.sh
```

Installs Homebrew, Python, Go, Node.js, Ollama, Claude CLI, tectonic, GitHub CLI.

### Phase 2 -- Clone, Configure, Start

```bash
gh auth login && claude login
./setup.sh
```

Clones repos, builds projects, prompts for secrets, installs LaunchAgent services.

### Phase 3 -- Verify

```bash
./health-check.sh
```

### Uninstall

```bash
./uninstall.sh
```

---

## Stack Versioning

Auspex pins service versions in `stack.json` for reproducible deployments. `setup.sh` checks out the exact pinned commits rather than pulling `main`.

```bash
# Bump a service to a specific commit
./scripts/bump-version.sh mini-claude-bot abc1234def5678

# Bump to current main HEAD
./scripts/bump-version.sh mini-claude-bot
```

Commit the updated `stack.json` to deploy. Revert to roll back.

---

## Directory Structure

```
auspex/
├── install.sh                # Phase 1: System dependencies
├── setup.sh                  # Phase 2: Project config + service startup
├── health-check.sh           # Phase 3: Verification
├── uninstall.sh              # Teardown
├── stack.json                # Pinned service versions
├── Brewfile                  # Homebrew dependencies
├── scripts/
│   └── bump-version.sh       # Version bump helper
├── launchd/                  # LaunchAgent plist templates
└── env/                      # Environment variable templates
```

---

## Data Migration

Copy from an existing machine:

```bash
scp old-mac:~/Projects/mini-claude-bot/data/mini-claude-bot.db ~/Projects/mini-claude-bot/data/
scp old-mac:~/.telegram-claude-hero.json ~/
scp -r old-mac:~/.claude/ ~/
```

---

## The Ecosystem

| Project | Role |
|---------|------|
| **Auspex** (you are here) | Mac provisioning |
| [**Centurion**](https://github.com/spacelobster88/centurion) | Fleet-level agent orchestration |
| [**mini-claude-bot**](https://github.com/spacelobster88/mini-claude-bot) | Claude gateway + memory + cron |
| [**telegram-claude-hero**](https://github.com/spacelobster88/telegram-claude-hero) | Telegram bot bridge |
| [**harness-loop**](https://github.com/spacelobster88/harness-loop) | Project development orchestrator |

---

## Release History

### v1.1.1-auto-restart (2026-03-19)

- Centurion LaunchAgent with `KeepAlive` + `RunAtLoad` auto-restart
- Templated plist generation, `CENTURION_HOST`/`CENTURION_PORT` env overrides

### v1.1.0 (2026-03-18) -- Reliability & Observability

- **Centurion**: `psutil`-based RAM estimation, compressor-aware pressure detection, `SessionRegistry` with parent-child tracking, `/closeable-sessions` endpoint
- **mini-claude-bot**: Fixed harness-loop chain stalls (#5, #6), metrics migrated to GitHub Gist
- **telegram-claude-hero**: `/resume` command, friendly chain-running message

### v1.0.0 (2026-03-16) -- First Stable Release

Full stack operational: Claude gateway with semantic memory, Telegram bridge, Centurion fleet orchestration, harness-loop parallel execution, daily financial reports, Vercel dashboard.

---

## Disclaimer

This script installs system-level software and modifies LaunchAgent configurations. Read each script before running. Any damage, data loss, or security incidents are the user's responsibility.

---

## License

MIT
