# 📡 openclaw-skill-meshtastic

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform: macOS](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)
![Meshtastic](https://img.shields.io/badge/Meshtastic-LoRa-green.svg)

> 🛰️ OpenClaw skill for interacting with a Meshtastic mesh network — send messages, monitor nodes, and check health from the command line.

## 🚀 Quick Start

```bash
# 1. Install to OpenClaw skills directory
cp -r . ~/.openclaw/workspace/skills/meshtastic/

# 2. Configure
cp config.env.example config.env
# Edit config.env with your paths and node ID

# 3. Make executable
chmod +x meshtastic.sh

# 4. Check status
./meshtastic.sh status
```

## 📋 Features

| Feature | Description |
|---------|-------------|
| 📤 **Send Messages** | Channel broadcast or direct messages to specific nodes |
| ↩️ **Auto-Reply** | Reply to the last received message (DM or channel) |
| 📬 **Inbox Queue** | View pending messages (auto-purged after webhook delivery) |
| 📊 **Status** | Daemon health, serial connection, message stats |
| 📡 **Node List** | Visible nodes with GPS, SNR, and last seen |
| 🏥 **Health JSON** | Machine-readable health check for automation |
| 📱 **Telegram Format** | TypeScript utilities for Telegram-ready output |

## 💡 Examples

### Send a message to the channel
```bash
./meshtastic.sh send --channel "Hello from OpenClaw! 📡"
```

### Send a direct message
```bash
./meshtastic.sh send --dm "!a1b2c3d4" "Hey, are you online?"
```

### Reply to the last message
```bash
./meshtastic.sh reply "Got it, thanks!"
```

### View pending messages (inbox = queue)
```bash
./meshtastic.sh inbox --tail 5        # Pending messages awaiting webhook delivery
./meshtastic.sh inbox --logs           # Full history from daemon logs
```

### Check daemon status
```bash
./meshtastic.sh status
# 📡 Meshtastic Status
#   🟢 Daemon: running (PID: 12345)
#   🟢 Serial: connected (/dev/cu.usbmodem3101)
#   📨 Last msg: 2025-02-18 23:45:12 (15m ago)
```

### Health check (JSON)
```bash
./meshtastic.sh health
# {"skill":"meshtastic","status":"ok","daemon_running":true,...}
```

### List mesh nodes
```bash
./meshtastic.sh nodes
# 📡 Mesh Nodes
#   Visible nodes: 3
#   !a1b2c3d4
#     📍 48.8566, 2.3522 (alt: 35m)  📶 SNR: 10.5  🕐 5m ago
```

## ⚙️ Configuration

Copy `config.env.example` to `config.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `MESH_INBOX` | `/tmp/mesh_inbox.txt` | Path to inbox file |
| `MESH_OUTBOX` | `/tmp/mesh_outbox.txt` | Path to outbox file |
| `MESH_POSITIONS` | `/tmp/mesh_positions.json` | Node positions JSON |
| `MESH_CONTEXT` | `/tmp/mesh_context.json` | Last message context |
| `MESH_NODE_ID` | `!your_node_id` | Your node identifier |
| `MESH_PORT` | `/dev/cu.usbmodem3101` | Serial port |
| `MESH_DAEMON_PROCESS` | `bridge.py` | Daemon process name |

## 🔧 Troubleshooting

**Daemon not running?**
```bash
# Check if the daemon is up
ps aux | grep bridge.py

# Restart it
cd ~/.openclaw/workspace/integrations/meshtastic-daemon
node dist/index.js
```

**Serial port not found?**
```bash
# List available serial ports
ls /dev/cu.usb*

# Update MESH_PORT in config.env
```

**No messages in inbox?**
```bash
# Check if inbox file exists and has content
cat /tmp/mesh_inbox.txt

# Check daemon logs
tail -20 /tmp/mesh_daemon.log
```

**jq not installed?**
```bash
brew install jq
```

## 📁 Architecture

This skill is a **wrapper** — it doesn't run its own daemon. It communicates with the existing `meshtastic-daemon` integration via shared files:

```
meshtastic.sh ──write──→ /tmp/mesh_outbox.txt ──→ Node.js watcher ──→ Python bridge ──→ Radio
                                                                            ↓
meshtastic.sh ←──read──── /tmp/mesh_inbox.txt  ←── Python bridge ←────── Radio
```

## 📄 License

MIT
