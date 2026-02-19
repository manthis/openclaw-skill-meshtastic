# 📡 Meshtastic Skill

**Purpose:** CLI wrapper around the Meshtastic daemon for easy mesh messaging, monitoring, and health checks.

## Overview

Provides a bash CLI (`meshtastic.sh`) to interact with the running Meshtastic daemon (Python bridge + Node.js watcher). Also includes TypeScript utilities for parsing, formatting, and stats.

**Inbox = temporary queue:** Messages appear in inbox on receive and are automatically purged after successful webhook delivery. Only unprocessed messages remain. Full message history is in the daemon's rotating logs (`meshtastic.sh inbox --logs`).

## Requirements

- **bash** (4.0+)
- **jq** — JSON processing (for nodes/health commands)
- **Meshtastic daemon** running (`integrations/meshtastic-daemon/`)

## Commands

```bash
# Send messages
meshtastic.sh send --channel "Hello mesh!"
meshtastic.sh send --dm "!a1b2c3d4" "Private message"
meshtastic.sh reply "Thanks!"

# Read pending messages (inbox = temporary queue, purged after webhook delivery)
meshtastic.sh inbox --tail 10
meshtastic.sh inbox --logs            # Full history from daemon logs

# Status & monitoring
meshtastic.sh status        # Human-readable status
meshtastic.sh nodes         # Visible nodes with positions/SNR
meshtastic.sh health        # JSON output for heartbeat integration
```

## 🤖 OpenClaw Auto-Reply Rules

**CRITICAL:** When replying to Meshtastic messages from OpenClaw:

### Use REPLY| prefix for context-aware replies

```bash
# ✅ CORRECT: Auto-replies to last message (DM → DM, channel → channel)
echo "REPLY|Got it, thanks!" > /tmp/mesh_outbox.txt

# ❌ WRONG: Always sends to public channel (ignores DM context)
echo "Got it, thanks!" > /tmp/mesh_outbox.txt
```

### How REPLY| works

- Daemon tracks last message context in `/tmp/mesh_context.json`
- `REPLY|text` → Sends to correct destination automatically
  - If last message was DM → sends DM back
  - If last message was channel → sends to channel
- Plain text (no prefix) → **always goes to public channel**

### Manual DM (without REPLY)

```bash
# Send DM to specific node (bypass context)
echo "DM|!69573c02|Private message" > /tmp/mesh_outbox.txt
```

**Rule of thumb:** Always use `REPLY|` when responding to Meshtastic messages in OpenClaw, unless you explicitly want to broadcast to the channel.

## Health Check Integration

For `HEARTBEAT.md`, use:
```bash
health=$(~/.openclaw/workspace/skills/meshtastic/meshtastic.sh health)
status=$(echo "$health" | jq -r '.status')
# status: "ok" | "warning" | "critical"
```

## TypeScript Utilities

`mesh-utils.ts` provides:
- `parseInbox(path)` — Parse inbox file into structured messages
- `formatForTelegram(messages)` — HTML-formatted messages for Telegram
- `parsePositions(path)` — Load node positions
- `positionsToHuman(path)` — Human-readable positions
- `computeStats(messages)` — Message statistics
- `formatStatsForTelegram(stats)` — Stats formatted for Telegram

## Configuration

Copy `config.env.example` to `config.env` and adjust paths. All paths default to `/tmp/mesh_*.txt`.

## File Layout

```
meshtastic/
├── SKILL.md              # This file
├── config.env.example    # Configuration template
├── config.env            # Local config (gitignored)
├── meshtastic.sh         # Main CLI
├── mesh-utils.ts         # TypeScript utilities
└── README.md             # Public documentation
```
