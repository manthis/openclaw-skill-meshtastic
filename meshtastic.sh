#!/usr/bin/env bash
# 📡 Meshtastic CLI — OpenClaw Skill
# Wrapper around the Meshtastic daemon for easy mesh messaging & monitoring
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# Defaults
MESH_INBOX="${MESH_INBOX:-/tmp/mesh_inbox.txt}"
MESH_OUTBOX="${MESH_OUTBOX:-/tmp/mesh_outbox.txt}"
MESH_POSITIONS="${MESH_POSITIONS:-/tmp/mesh_positions.json}"
MESH_CONTEXT="${MESH_CONTEXT:-/tmp/mesh_context.json}"
MESH_LOG="${MESH_LOG:-/tmp/mesh_daemon.log}"
MESH_NODE_ID="${MESH_NODE_ID:-!04c54494}"
MESH_DAEMON_PROCESS="${MESH_DAEMON_PROCESS:-bridge.py}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  cat <<EOF
📡 ${BOLD}Meshtastic CLI${NC} — OpenClaw Skill

${BOLD}Usage:${NC}
  meshtastic.sh <command> [options]

${BOLD}Commands:${NC}
  ${CYAN}send${NC}     --channel "msg"          Send to channel
  ${CYAN}send${NC}     --dm <nodeId> "msg"       Send DM to node
  ${CYAN}reply${NC}    "msg"                     Reply to last message
  ${CYAN}inbox${NC}    [--tail N] [--logs]        Show pending messages (or history with --logs)
  ${CYAN}status${NC}                             Daemon & connection status
  ${CYAN}nodes${NC}                              List visible mesh nodes
  ${CYAN}health${NC}                             JSON health check (for heartbeat)
  ${CYAN}help${NC}                               Show this help

${BOLD}Examples:${NC}
  meshtastic.sh send --channel "Hello mesh!"
  meshtastic.sh send --dm "!a1b2c3d4" "Hey there"
  meshtastic.sh reply "Got it, thanks!"
  meshtastic.sh inbox --tail 5
  meshtastic.sh inbox --logs          # Full history from daemon logs
  meshtastic.sh status
EOF
}

# ── Send ──────────────────────────────────────────────
cmd_send() {
  local mode="" dest="" msg=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --channel|-c) mode="channel"; shift ;;
      --dm|-d) mode="dm"; dest="$2"; shift 2 ;;
      *) msg="$1"; shift ;;
    esac
  done

  if [[ -z "$msg" ]]; then
    echo -e "${RED}Error:${NC} No message provided" >&2
    return 1
  fi

  case "$mode" in
    channel)
      echo "$msg" >> "$MESH_OUTBOX"
      echo -e "${GREEN}📤${NC} Sent to channel: ${BOLD}$msg${NC}"
      ;;
    dm)
      if [[ -z "$dest" ]]; then
        echo -e "${RED}Error:${NC} No destination node ID for DM" >&2
        return 1
      fi
      echo "DM|${dest}|${msg}" >> "$MESH_OUTBOX"
      echo -e "${GREEN}📤${NC} DM to ${CYAN}${dest}${NC}: ${BOLD}$msg${NC}"
      ;;
    *)
      echo -e "${RED}Error:${NC} Specify --channel or --dm <nodeId>" >&2
      return 1
      ;;
  esac
}

# ── Reply ─────────────────────────────────────────────
cmd_reply() {
  local msg="${1:-}"
  if [[ -z "$msg" ]]; then
    echo -e "${RED}Error:${NC} No message provided" >&2
    return 1
  fi

  echo "REPLY|${msg}" >> "$MESH_OUTBOX"
  
  # Show context if available
  if [[ -f "$MESH_CONTEXT" ]] && command -v jq &>/dev/null; then
    local from isDM
    from=$(jq -r '.fromId // "unknown"' "$MESH_CONTEXT" 2>/dev/null)
    isDM=$(jq -r '.isDM // false' "$MESH_CONTEXT" 2>/dev/null)
    if [[ "$isDM" == "true" ]]; then
      echo -e "${GREEN}↩️${NC}  Reply DM to ${CYAN}${from}${NC}: ${BOLD}$msg${NC}"
    else
      echo -e "${GREEN}↩️${NC}  Reply to channel (last from ${CYAN}${from}${NC}): ${BOLD}$msg${NC}"
    fi
  else
    echo -e "${GREEN}↩️${NC}  Reply queued: ${BOLD}$msg${NC}"
  fi
}

# ── Inbox (pending queue) ─────────────────────────────
cmd_inbox() {
  local tail_n=20 show_logs=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tail|-n) tail_n="$2"; shift 2 ;;
      --logs|-l) show_logs=true; shift ;;
      --unread|-u) shift ;; # kept for compat, no-op (inbox is now a queue)
      *) shift ;;
    esac
  done

  # --logs: show history from daemon log instead of inbox queue
  if [[ "$show_logs" == "true" ]]; then
    if [[ ! -f "$MESH_LOG" ]]; then
      echo -e "${YELLOW}📭${NC} No daemon log found at ${MESH_LOG}"
      return 0
    fi
    echo -e "${BOLD}📜 Message History${NC} (from daemon logs, last ${tail_n})"
    echo ""
    grep -E '(✉️|📩)' "$MESH_LOG" | tail -n "$tail_n" | while IFS= read -r line; do
      echo -e "  ${line}"
    done
    return 0
  fi

  if [[ ! -f "$MESH_INBOX" ]]; then
    echo -e "${YELLOW}📭${NC} No inbox file found at ${MESH_INBOX}"
    return 0
  fi

  local count
  count=$(grep -c . "$MESH_INBOX" 2>/dev/null || echo "0")
  
  if [[ "$count" -eq 0 ]]; then
    echo -e "${GREEN}✅${NC} Aucun message en attente de traitement"
    return 0
  fi

  echo -e "${BOLD}📬 Messages en attente de traitement${NC} (${count} pending)"
  echo ""

  tail -n "$tail_n" "$MESH_INBOX" | while IFS='|' read -r ts type from text; do
    [[ -z "$ts" ]] && continue
    local date_str icon
    date_str=$(date -r "$ts" "+%m/%d %H:%M" 2>/dev/null || echo "$ts")
    
    if [[ "$type" == "DM" ]]; then
      icon="🔒"
    else
      icon="📢"
    fi
    
    # Highlight if from another node
    if [[ "$from" != "$MESH_NODE_ID" ]]; then
      echo -e "  ${icon} ${YELLOW}${date_str}${NC} ${CYAN}${from}${NC} → ${text}"
    else
      echo -e "  ${icon} ${YELLOW}${date_str}${NC} ${GREEN}me${NC} → ${text}"
    fi
  done
}

# ── Status ────────────────────────────────────────────
cmd_status() {
  echo -e "${BOLD}📡 Meshtastic Status${NC}"
  echo ""

  # Daemon check
  local daemon_pid
  daemon_pid=$(pgrep -f "$MESH_DAEMON_PROCESS" 2>/dev/null || true)
  if [[ -n "$daemon_pid" ]]; then
    echo -e "  🟢 Daemon: ${GREEN}running${NC} (PID: ${daemon_pid})"
  else
    echo -e "  🔴 Daemon: ${RED}not running${NC}"
  fi

  # Node.js watcher check
  local watcher_pid
  watcher_pid=$(pgrep -f "meshtastic-daemon/dist/index.js" 2>/dev/null || true)
  if [[ -n "$watcher_pid" ]]; then
    echo -e "  🟢 Watcher: ${GREEN}running${NC} (PID: ${watcher_pid})"
  else
    echo -e "  🔴 Watcher: ${RED}not running${NC}"
  fi

  # Serial port
  local port="${MESH_PORT:-/dev/cu.usbmodem3101}"
  if [[ -e "$port" ]]; then
    echo -e "  🟢 Serial: ${GREEN}connected${NC} (${port})"
  else
    echo -e "  🔴 Serial: ${RED}not found${NC} (${port})"
  fi

  # Last message
  if [[ -f "$MESH_INBOX" ]]; then
    local last_line last_ts
    last_line=$(tail -1 "$MESH_INBOX" 2>/dev/null)
    last_ts=$(echo "$last_line" | cut -d'|' -f1)
    if [[ -n "$last_ts" && "$last_ts" =~ ^[0-9]+$ ]]; then
      local last_date ago_s ago_str
      last_date=$(date -r "$last_ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
      ago_s=$(( $(date +%s) - last_ts ))
      if (( ago_s < 60 )); then
        ago_str="${ago_s}s ago"
      elif (( ago_s < 3600 )); then
        ago_str="$(( ago_s / 60 ))m ago"
      elif (( ago_s < 86400 )); then
        ago_str="$(( ago_s / 3600 ))h ago"
      else
        ago_str="$(( ago_s / 86400 ))d ago"
      fi
      echo -e "  📨 Last msg: ${YELLOW}${last_date}${NC} (${ago_str})"
    fi
    local msg_count
    msg_count=$(wc -l < "$MESH_INBOX" | tr -d ' ')
    echo -e "  📊 Queue: ${msg_count} pending"
  else
    echo -e "  📭 Inbox: ${YELLOW}no messages yet${NC}"
  fi

  # Node ID
  echo -e "  🆔 Node: ${CYAN}${MESH_NODE_ID}${NC}"
}

# ── Nodes ─────────────────────────────────────────────
cmd_nodes() {
  echo -e "${BOLD}📡 Mesh Nodes${NC}"
  echo ""

  if [[ ! -f "$MESH_POSITIONS" ]]; then
    echo -e "  ${YELLOW}No positions file found${NC}"
    echo -e "  Expected: ${MESH_POSITIONS}"
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    echo -e "  ${RED}jq required${NC} — install with: brew install jq"
    return 1
  fi

  local count
  count=$(jq 'length' "$MESH_POSITIONS" 2>/dev/null || echo "0")
  echo -e "  Visible nodes: ${BOLD}${count}${NC}"
  echo ""

  jq -r 'to_entries[] | "\(.key)|\(.value.lat // "?")|\(.value.lon // "?")|\(.value.alt // "?")|\(.value.snr // "?")|\(.value.lastSeen // 0)"' "$MESH_POSITIONS" 2>/dev/null | while IFS='|' read -r nodeId lat lon alt snr lastSeen; do
    local seen_str="?"
    if [[ "$lastSeen" =~ ^[0-9]+$ ]] && (( lastSeen > 0 )); then
      local ago=$(( $(date +%s) - lastSeen ))
      if (( ago < 60 )); then seen_str="${ago}s ago"
      elif (( ago < 3600 )); then seen_str="$(( ago / 60 ))m ago"
      elif (( ago < 86400 )); then seen_str="$(( ago / 3600 ))h ago"
      else seen_str="$(( ago / 86400 ))d ago"
      fi
    fi
    echo -e "  ${CYAN}${nodeId}${NC}"
    echo -e "    📍 ${lat}, ${lon} (alt: ${alt}m)  📶 SNR: ${snr}  🕐 ${seen_str}"
  done
}

# ── Health (JSON) ─────────────────────────────────────
cmd_health() {
  local daemon_running="false"
  local watcher_running="false"
  local serial_connected="false"
  local last_msg_ts=0
  local msg_count=0
  local status="ok"
  local alerts="[]"

  # Daemon check
  if pgrep -f "$MESH_DAEMON_PROCESS" &>/dev/null; then
    daemon_running="true"
  fi

  # Watcher check
  if pgrep -f "meshtastic-daemon/dist/index.js" &>/dev/null; then
    watcher_running="true"
  fi

  # Serial
  local port="${MESH_PORT:-/dev/cu.usbmodem3101}"
  if [[ -e "$port" ]]; then
    serial_connected="true"
  fi

  # Last message
  if [[ -f "$MESH_INBOX" ]]; then
    msg_count=$(wc -l < "$MESH_INBOX" | tr -d ' ')
    local last_line
    last_line=$(tail -1 "$MESH_INBOX" 2>/dev/null)
    last_msg_ts=$(echo "$last_line" | cut -d'|' -f1)
    [[ ! "$last_msg_ts" =~ ^[0-9]+$ ]] && last_msg_ts=0
  fi

  # Determine alerts
  local alert_items=()
  if [[ "$daemon_running" == "false" ]]; then
    status="critical"
    alert_items+=("\"daemon_down\"")
  fi
  if [[ "$serial_connected" == "false" ]]; then
    status="warning"
    alert_items+=("\"serial_disconnected\"")
  fi
  if (( last_msg_ts > 0 )); then
    local stale=$(( $(date +%s) - last_msg_ts ))
    if (( stale > 86400 )); then
      [[ "$status" == "ok" ]] && status="warning"
      alert_items+=("\"inbox_stale_${stale}s\"")
    fi
  fi

  # Build alerts JSON array
  if (( ${#alert_items[@]} > 0 )); then
    alerts=$(printf '%s,' "${alert_items[@]}")
    alerts="[${alerts%,}]"
  fi

  cat <<EOF
{
  "skill": "meshtastic",
  "status": "${status}",
  "daemon_running": ${daemon_running},
  "watcher_running": ${watcher_running},
  "serial_connected": ${serial_connected},
  "node_id": "${MESH_NODE_ID}",
  "message_count": ${msg_count},
  "last_message_ts": ${last_msg_ts},
  "alerts": ${alerts},
  "checked_at": $(date +%s)
}
EOF
}

# ── Main ──────────────────────────────────────────────
case "${1:-help}" in
  send)   shift; cmd_send "$@" ;;
  reply)  shift; cmd_reply "$@" ;;
  inbox)  shift; cmd_inbox "$@" ;;
  status) cmd_status ;;
  nodes)  cmd_nodes ;;
  health) cmd_health ;;
  help|--help|-h) usage ;;
  *)
    echo -e "${RED}Unknown command:${NC} $1" >&2
    usage
    exit 1
    ;;
esac
