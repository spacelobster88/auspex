---
name: stack-snapshot
description: >
  Use when the user wants to take a snapshot of the current Auspex stack,
  list existing snapshots, restore to a previous snapshot, or says
  "snapshot", "tag the stack", "freeze versions", "rollback stack",
  "list snapshots", or "restore snapshot". Manages coordinated version
  tagging across all microservices (mini-claude-bot, telegram-claude-hero,
  centurion, harness-loop, smart-email-responder, auspex).
version: 0.1.0
---

# Stack Snapshot Skill

Manage coordinated version snapshots across the Auspex microservice stack.

## What this skill does

Each snapshot:
1. Tags every service repo with the same version tag (annotated)
2. Pushes tags to GitHub
3. Updates `stack.json` with the tag refs
4. Captures sanitized environment variables (tuning params only, NO secrets/tokens/PII)
5. Commits and tags `auspex` itself

Snapshot artifacts are stored at `auspex/snapshots/<version>/`:
```
snapshots/v1.0.0/
├── manifest.json              # Snapshot metadata
└── env/
    ├── mini-claude-bot.env    # Sanitized .env (secrets → REDACTED)
    ├── centurion.env
    └── launchd-env.txt        # LaunchAgent env vars
```

## Commands

### Take a snapshot

```bash
bash ~/Projects/auspex/skills/stack-snapshot/scripts/snapshot.sh <version> [message]
```

- `<version>`: Semantic version like `v1.0.0`, `v1.1.0-rc1`, etc.
- `[message]`: Optional annotation message. Defaults to "Stack snapshot <version>"

### List snapshots

```bash
bash ~/Projects/auspex/skills/stack-snapshot/scripts/list.sh
```

### Restore to a snapshot

```bash
bash ~/Projects/auspex/skills/stack-snapshot/scripts/restore.sh <version>
```

## Workflow

When the user asks to take a snapshot:

1. Ask what version string to use (suggest next logical version based on existing tags)
2. Ask for an optional description/message
3. Run the snapshot script with the provided arguments
4. Report results

When the user asks to list snapshots:
- Run list script and present results in a table

When the user asks to restore:
1. Run list script first to show available versions
2. Confirm which version to restore
3. Run restore script after confirmation
4. Report results

## Configuration

All repos are expected at `~/Projects/<repo-name>`. The service list is read from
`~/Projects/auspex/stack.json`.
