---
name: save-knowledge
description: >
  Save operational knowledge, learnings, and system insights to the
  auspex knowledge base. Use when the user says "save this knowledge",
  "remember this", "document this learning", "save to knowledge base",
  or wants to capture system behavior, debugging patterns, or
  architectural understanding for future reference.
version: 0.1.0
---

# Save Knowledge Skill

Capture and persist operational knowledge into the Auspex knowledge base.

## What this skill does

1. Takes raw knowledge (from conversation, debugging sessions, or operational experience)
2. Summarizes it into a structured markdown document with clear sections
3. Saves it to `~/Projects/auspex/knowledge/<slug>.md`
4. Commits the change to git
5. Pushes to the GitHub repo

## Knowledge document format

Each knowledge file should follow this structure:

```markdown
# Title

**Date:** YYYY-MM-DD
**Source:** Brief description of where this knowledge came from

## Summary
One paragraph overview.

## Details
Structured content with tables, code blocks, diagrams as appropriate.

## Operational Implications
How this knowledge affects day-to-day operations.

## Recommended Practice
Actionable takeaways.
```

## Workflow

When the user asks to save knowledge:

1. **Identify the knowledge**: Extract the key insight from the conversation
2. **Generate a slug**: Create a kebab-case filename (e.g., `gateway-session-lifecycle`)
3. **Check for duplicates**: Look in `~/Projects/auspex/knowledge/` for existing files on the same topic
   - If found, update the existing file rather than creating a new one
4. **Summarize**: Write a structured markdown document following the format above
5. **Save**: Write to `~/Projects/auspex/knowledge/<slug>.md`
6. **Commit**: Stage and commit with message `knowledge: <brief description>`
7. **Push**: Push to origin

## Commands

### Save knowledge (automated by this skill)

```bash
# The skill handles this automatically, but manually:
# 1. Write the file
# 2. cd ~/Projects/auspex
# 3. git add knowledge/<slug>.md
# 4. git commit -m "knowledge: <description>"
# 5. git push
```

### List existing knowledge

```bash
ls ~/Projects/auspex/knowledge/
```

### Search knowledge

```bash
grep -rl "<search term>" ~/Projects/auspex/knowledge/
```

## Configuration

Knowledge files are stored at `~/Projects/auspex/knowledge/`.
The repo is at `~/Projects/auspex` with remote `origin` on GitHub.
