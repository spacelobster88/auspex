# Auspex

**One who reads the signs and prepares the ground. Bootstrap a fresh Mac with your AI agent service stack.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Latest: v1.1.1-auto-restart](https://img.shields.io/badge/Latest-v1.1.1--auto--restart-brightgreen.svg)](https://github.com/spacelobster88/auspex/releases/tag/v1.1.1-auto-restart)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)]()
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2B-black.svg)]()
[![Services](https://img.shields.io/badge/Services-6-orange.svg)]()
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Opus%204.6-blueviolet.svg)]()

> *Before Rome's legions marched, before the Senate voted, the auspex read the signs -- the flight of birds, the state of the sky -- and declared the ground fit for action. Auspex does the same for your Mac: it reads the machine, installs every dependency, and prepares the ground so your AI services can march in formation from the first command.*

Auspex transforms a bare Mac -- Mini, MacBook, or Studio -- into a fully operational AI service hub. It installs dependencies, clones projects, configures secrets, and starts persistent services, all in three phases.

---

## Disclaimer

**This script installs system-level software, modifies LaunchAgents configuration, and writes files to your HOME directory.**

Risks include but are not limited to:
- System configuration changes
- Conflicts with existing software
- High resource usage from runaway services
- Security issues from misconfigured keys/tokens

**Any system damage, data loss, service disruption, or security incidents caused by using these scripts are entirely the user's responsibility. The developer assumes no liability whatsoever.**

Read each script carefully before running. Make sure you understand every step.

---

## Hardware Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| Chip | Apple Silicon (M1+) | M2 / M4 |
| RAM | 16 GB | 32 GB+ (each Claude agent uses ~250 MB) |
| Disk | 30 GB free | 100 GB+ (Ollama models, brew packages, project code) |
| macOS | 14.0 (Sonoma)+ | Latest |
| Mac type | Mac Mini, MacBook, Mac Studio, Mac Pro | Any Apple Silicon Mac |

## What Gets Deployed

```
┌──────────────────────────────────────────────────────────┐
│                       Your Mac                           │
│                                                          │
│  Ollama (11434)              <- Vector embeddings        │
│    └──> mini-claude-bot (8000)    <- Claude gateway      │
│           ├──> telegram-claude-hero    <- Telegram bridge │
│           └──> smart-email-responder   <- Email agent    │
│                                                          │
│  Centurion (8100)            <- Agent fleet orchestrator │
│                                                          │
│  Harness Loop (.harness/)    <- Project orchestrator     │
└──────────────────────────────────────────────────────────┘
```

### The Legion -- Services Bootstrapped by Auspex

| Service | Stack | Port | Description |
|---------|-------|------|-------------|
| [Ollama](https://ollama.com/) | Homebrew | 11434 | nomic-embed-text model, provides vector embeddings for mini-claude-bot |
| [mini-claude-bot](https://github.com/spacelobster88/mini-claude-bot) | Python 3.13 / FastAPI | 8000 | Multi-session Claude gateway, cron scheduling, semantic memory, daily reports |
| [telegram-claude-hero](https://github.com/spacelobster88/telegram-claude-hero) | Go 1.25 | - | Telegram Bot bridge, forwards messages to mini-claude-bot |
| [smart-email-responder](https://github.com/spacelobster88/smart-email-responder) | Python / FastAPI | - | AI-powered email drafting and response agent |
| [centurion](https://github.com/spacelobster88/centurion) | Python 3.12+ / FastAPI | 8100 | AI Agent orchestration engine, manages multiple Claude CLI processes |
| [harness-loop](https://github.com/spacelobster88/harness-loop) | Node.js | - | Project-level orchestrator, drives iterative development loops |

## Usage

### Phase 0: Manual Prerequisites

These steps cannot be automated and must be done before running scripts:

1. **macOS permissions** (System Settings -> Privacy & Security):
   - Grant Terminal.app or iTerm2: **Accessibility**
   - Grant Terminal.app or iTerm2: **Full Disk Access**
   - Grant Terminal.app or iTerm2: **Automation**

2. **Have the following ready**:
   - GitHub account (for cloning private repos)
   - Telegram Bot Token (from [@BotFather](https://t.me/BotFather))
   - Anthropic account (for Claude CLI login)

### Phase 1: Install System Dependencies

```bash
git clone https://github.com/spacelobster88/auspex.git
cd auspex
chmod +x *.sh
./install.sh
```

Installs: Homebrew, Python, Go, Node.js, Ollama, Claude CLI, tectonic (LaTeX), GitHub CLI.

### Phase 2: Clone Projects + Configure + Start Services

```bash
# Complete GitHub and Claude login first
gh auth login
claude login

# Then run
./setup.sh
```

The script will interactively guide you to:
- Clone project repos (mini-claude-bot, telegram-claude-hero, smart-email-responder, centurion, harness-loop)
- Build each project (Python venv, Go build, npm install)
- Enter Telegram Bot Token and other secrets
- Install and start LaunchAgent services

### Phase 3: Verify

```bash
./health-check.sh
```

Verifies all services are running correctly.

### Uninstall

```bash
./uninstall.sh
```

Stops all services and removes LaunchAgent configurations.

## Stack Versioning

Auspex uses an umbrella manifest (`stack.json`) to pin compatible versions of all microservices. This ensures reproducible deployments -- every `setup.sh` run checks out the exact commits recorded in `stack.json` rather than pulling whatever happens to be on `main`.

### How It Works

- `stack.json` at the repo root lists every service with its GitHub repo, pinned commit SHA, version string, and dependencies.
- `setup.sh` reads `stack.json` and checks out the pinned ref for each service.
- To update a service after merging changes, run the bump script:

```bash
# Pin to a specific commit
./scripts/bump-version.sh mini-claude-bot abc1234def5678

# Pin to current main HEAD (fetched from GitHub)
./scripts/bump-version.sh mini-claude-bot
```

- Commit and push the updated `stack.json`. The next `setup.sh` run on any machine will deploy the new version.
- To roll back, revert the `stack.json` commit.

### Stack Version

The top-level `stack_version` field in `stack.json` tracks the overall stack release. Bump it when you cut a coordinated release across services.

## Directory Structure

```
auspex/
├── README.md                 # This document
├── LICENSE                   # MIT
├── stack.json                # Pinned service versions (the version manifest)
├── install.sh                # Phase 1: System dependencies
├── setup.sh                  # Phase 2: Project config + service startup
├── health-check.sh           # Phase 3: Service verification
├── uninstall.sh              # Teardown
├── Brewfile                  # Homebrew dependency manifest
├── scripts/
│   └── bump-version.sh       # Helper to update pinned versions
├── launchd/                  # LaunchAgent plist templates
│   ├── com.eddie.ollama.plist.template
│   ├── com.eddie.mini-claude-bot.plist.template
│   ├── com.eddie.telegram-claude-hero.plist.template
│   └── com.eddie.centurion.plist.template
└── env/                      # Environment variable templates
    ├── mini-claude-bot.env.example
    └── centurion.env.example
```

## The Centurion Ecosystem

Auspex is the groundwork layer -- the augur's preparation -- for the broader AI agent stack:

| Project | Role | Link |
|---------|------|------|
| **Auspex** | Mac provisioning (you are here) | [GitHub](https://github.com/spacelobster88/auspex) |
| **Centurion** | Fleet-level agent orchestration (100+ agents) | [GitHub](https://github.com/spacelobster88/centurion) |
| **mini-claude-bot** | Claude gateway + memory + cron | [GitHub](https://github.com/spacelobster88/mini-claude-bot) |
| **telegram-claude-hero** | Telegram bot bridge | [GitHub](https://github.com/spacelobster88/telegram-claude-hero) |
| **smart-email-responder** | AI email drafting agent | [GitHub](https://github.com/spacelobster88/smart-email-responder) |
| **harness-loop** | Project-level development orchestrator | [GitHub](https://github.com/spacelobster88/harness-loop) |

## Manual Steps Checklist

The following require browser interaction or manual configuration. Scripts will prompt at the appropriate time:

| Step | Command / Action | Notes |
|------|-----------------|-------|
| GitHub login | `gh auth login` | Required for cloning private repos |
| Claude login | `claude login` | Requires Anthropic account, browser interaction |
| macOS permissions | System Settings -> Privacy & Security | Terminal/iTerm2 needs Accessibility + Full Disk Access + Automation |
| Telegram Token | @BotFather | setup.sh will prompt for input |
| Gmail App Password | Google Account settings | Only needed for daily report emails |

## Data Migration (Optional)

If migrating from an old machine, copy the following:

```bash
# Chat history + memory database
scp old-mac:~/Projects/mini-claude-bot/data/mini-claude-bot.db \
    ~/Projects/mini-claude-bot/data/

# Telegram config (contains bot token)
scp old-mac:~/.telegram-claude-hero.json ~/

# Claude config
scp -r old-mac:~/.claude/ ~/
```

## Release History

### v1.1.1-auto-restart (2026-03-19) — LaunchAgent Auto-Restart

**Centurion**
- Added `scripts/install-launchd.sh` — one-command install/uninstall of Centurion as a macOS LaunchAgent
- LaunchAgent configured with `KeepAlive` (auto-restart on crash) and `RunAtLoad` (start on boot)
- Supports `CENTURION_HOST` / `CENTURION_PORT` env var overrides
- Templated plist generation (paths derived from project location, not hardcoded)

**Stack**
| Service | Commit |
|---------|--------|
| mini-claude-bot | `29f6450` |
| telegram-claude-hero | `e397ffb` |
| centurion | `bf96eda` |
| smart-email-responder | `09c7438` |
| harness-loop | `e81eb24` |

---

### v1.1.0 (2026-03-18) — Reliability & Observability

**Centurion**
- Replaced fragile `vm_stat` parsing with `psutil` for accurate RAM estimation
- Added compressor-aware memory pressure detection (30% → WARN, 50% → CRITICAL)
- New `SessionRegistry` with parent-child relationship tracking
- New `GET /closeable-sessions` endpoint + `recommended_actions` in health response
- Added Hardware Engineer + Product Manager subagent roles to `CLAUDE.md`

**mini-claude-bot**
- Fixed harness-loop chain stall: self-blocking race condition (#5)
- Fixed harness-loop chain stall: manual Resume overwriting active chain (#6)
- Dashboard metrics migrated from Vercel Edge Config → GitHub Gist (rate limit fix)
- Metrics push interval changed from 1 min → 5 min

**telegram-claude-hero**
- New `/resume` command — routes harness resume directly to background (avoids foreground marker loss)
- Friendly "Chain is already running" message instead of raw rejection

**Stack**
| Service | Commit |
|---------|--------|
| mini-claude-bot | `29f6450` |
| telegram-claude-hero | `e397ffb` |
| centurion | `f944db0` |
| smart-email-responder | `09c7438` |
| harness-loop | `e81eb24` |

---

### v1.0.0 (2026-03-16) — First Stable Release

The full Auspex stack operational end-to-end:
- Multi-session Claude gateway with semantic memory and cron scheduling
- Telegram bot bridge with streaming responses and image/voice/document support
- Centurion agent fleet orchestration with K8s-inspired admission control
- Harness-loop project orchestrator with parallel task execution and QA feedback loops
- Smart email responder with AI-powered drafting
- Daily financial intelligence reports (CN/EN) with PDF generation and email delivery
- Vercel dashboard for real-time system monitoring
- Stack snapshot and restore tooling

**Stack**
| Service | Commit |
|---------|--------|
| mini-claude-bot | `4331538` |
| telegram-claude-hero | `f1fa9e8` |
| centurion | `6ba2db8` |
| smart-email-responder | `b82dddf` |
| harness-loop | `cae348c` |

---

## License

MIT
