# Gateway Session Lifecycle

**Date:** 2026-03-19
**Source:** Operational experience managing mini-claude-bot gateway sessions

## Session Types

| Prefix | Type | Source |
|--------|------|--------|
| `-100xxxxxxxxx` (bare negative ID) | Interactive | Telegram group chat — one long-lived `claude --resume` process per group |
| `bg--100xxx-xxxxxxxx` | Background | Spawned by harness-loop or `[HARNESS_EXEC_READY]` — separate Claude CLI with `--continue` |
| `fg--100xxx` | Foreground | Resumed interactive session after background task completes and reports back |
| Positive ID (e.g. `6838572051`) | Direct/Private | Personal DM with the bot |

## Session States

| State | Meaning | CPU | RAM |
|-------|---------|-----|-----|
| **busy** | Claude CLI actively processing (thinking, tools, output) | High | High |
| **idle** | Claude CLI process alive, waiting for next message | None | **Still consumed** |

## Key Insight: Idle Sessions Are NOT Free

Each idle Claude CLI process keeps resident in memory:
- Node.js runtime (~100-200MB base)
- Full conversation context
- Loaded tools and MCP connections

5 idle interactive sessions = **500MB-1GB+ of RAM** doing nothing.

## Lifecycle Flow

```
User sends message in Telegram group
    │
    ├── Session exists for this chat_id?
    │   ├── YES → pipe message to existing claude process (goes busy)
    │   └── NO  → spawn new `claude --resume` process (interactive)
    │
    ▼
Claude finishes responding → session goes idle
    └── Process stays alive, waiting for next message
        └── RAM still consumed until explicitly stopped
```

## Background Task Flow

```
User confirms plan → gateway detects [HARNESS_EXEC_READY]
    │
    ├── Spawns bg--{chat_id}-{uuid} with `claude --continue`
    │   └── Runs independently of interactive session
    │
    ▼
Background task completes
    ├── Results sent back to Telegram group
    ├── fg--{chat_id} session may be created for follow-up
    └── bg- session stays alive (idle) until explicitly stopped
```

## Operational Implications

1. **Memory pressure**: On a 16GB Mac Mini, each idle session wastes ~100-200MB. With 5+ groups active, this adds up fast.
2. **Cleanup discipline**: Stale `bg-` sessions must be manually stopped — they never auto-terminate.
3. **Session priority for cleanup** (from CLAUDE.md):
   - Stale/idle interactive sessions → close FIRST
   - Active interactive sessions → close second
   - Background Claude sessions → close LAST (highest priority)

## Recommended Practice

- Periodically run `list_gateway_sessions` to audit idle sessions
- Kill `bg-` sessions that have been idle for >30 minutes
- Consider auto-cleanup for sessions idle beyond a configurable threshold
