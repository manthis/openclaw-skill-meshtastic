# 📡 Meshtastic Skill

**Purpose:** CLI wrapper around the Meshtastic daemon for easy mesh messaging, monitoring, and health checks.

## Overview

Provides a bash CLI (`meshtastic.sh`) to interact with the running Meshtastic daemon (Python bridge + Node.js watcher). Also includes TypeScript utilities for parsing, formatting, and stats.

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

# Read inbox
meshtastic.sh inbox --tail 10 --unread

# Status & monitoring
meshtastic.sh status        # Human-readable status
meshtastic.sh nodes         # Visible nodes with positions/SNR
meshtastic.sh health        # JSON output for heartbeat integration
```

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
