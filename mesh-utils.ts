/**
 * 📡 Meshtastic TypeScript Utilities
 * Parser, formatter, and stats for mesh data
 */

import * as fs from "fs";

// ── Types ────────────────────────────────────────────

export interface InboxMessage {
  timestamp: number;
  type: "CH" | "DM";
  fromId: string;
  text: string;
}

export interface NodePosition {
  lat: number;
  lon: number;
  alt: number;
  snr?: number;
  lastSeen?: number;
  batteryLevel?: number;
}

export interface MeshStats {
  totalMessages: number;
  dmCount: number;
  channelCount: number;
  uniqueNodes: string[];
  lastMessageTs: number;
  messagesPerHour: number;
}

// ── Inbox Parser ─────────────────────────────────────

export function parseInbox(filePath: string): InboxMessage[] {
  if (!fs.existsSync(filePath)) return [];
  
  return fs.readFileSync(filePath, "utf-8")
    .split("\n")
    .filter(line => line.trim())
    .map(line => {
      const parts = line.split("|");
      if (parts.length < 4) return null;
      const timestamp = parseInt(parts[0], 10);
      const type = parts[1] as "CH" | "DM";
      if (type !== "CH" && type !== "DM") return null;
      if (isNaN(timestamp)) return null;
      return {
        timestamp,
        type,
        fromId: parts[2],
        text: parts.slice(3).join("|"),
      };
    })
    .filter((m): m is InboxMessage => m !== null);
}

// ── Telegram Formatter ───────────────────────────────

export function formatForTelegram(messages: InboxMessage[]): string {
  if (messages.length === 0) return "📭 No messages";

  return messages.map(m => {
    const date = new Date(m.timestamp * 1000);
    const time = date.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
    const icon = m.type === "DM" ? "🔒" : "📢";
    return `${icon} <b>${time}</b> <code>${m.fromId}</code>\n${m.text}`;
  }).join("\n\n");
}

export function formatStatusForTelegram(health: Record<string, any>): string {
  const status = health.status === "ok" ? "🟢" : health.status === "warning" ? "🟡" : "🔴";
  const lines = [
    `📡 <b>Meshtastic ${status}</b>`,
    `Daemon: ${health.daemon_running ? "✅" : "❌"}`,
    `Serial: ${health.serial_connected ? "✅" : "❌"}`,
    `Messages: ${health.message_count}`,
  ];
  if (health.alerts?.length > 0) {
    lines.push(`⚠️ ${health.alerts.join(", ")}`);
  }
  return lines.join("\n");
}

// ── Position Tracking ────────────────────────────────

export function parsePositions(filePath: string): Record<string, NodePosition> {
  if (!fs.existsSync(filePath)) return {};
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf-8"));
  } catch {
    return {};
  }
}

export function formatPosition(nodeId: string, pos: NodePosition): string {
  const parts = [`📍 ${nodeId}: ${pos.lat.toFixed(6)}, ${pos.lon.toFixed(6)}`];
  if (pos.alt) parts.push(`alt ${pos.alt}m`);
  if (pos.snr !== undefined) parts.push(`SNR ${pos.snr}`);
  if (pos.lastSeen) {
    const ago = Math.floor((Date.now() / 1000 - pos.lastSeen) / 60);
    parts.push(`${ago}min ago`);
  }
  return parts.join(" | ");
}

export function positionsToHuman(filePath: string): string {
  const positions = parsePositions(filePath);
  const entries = Object.entries(positions);
  if (entries.length === 0) return "No nodes with positions";
  return entries.map(([id, pos]) => formatPosition(id, pos)).join("\n");
}

// ── Stats ────────────────────────────────────────────

export function computeStats(messages: InboxMessage[]): MeshStats {
  if (messages.length === 0) {
    return {
      totalMessages: 0,
      dmCount: 0,
      channelCount: 0,
      uniqueNodes: [],
      lastMessageTs: 0,
      messagesPerHour: 0,
    };
  }

  const dmCount = messages.filter(m => m.type === "DM").length;
  const uniqueNodes = [...new Set(messages.map(m => m.fromId))];
  const lastMessageTs = Math.max(...messages.map(m => m.timestamp));
  const firstMessageTs = Math.min(...messages.map(m => m.timestamp));
  const hours = Math.max(1, (lastMessageTs - firstMessageTs) / 3600);

  return {
    totalMessages: messages.length,
    dmCount,
    channelCount: messages.length - dmCount,
    uniqueNodes,
    lastMessageTs,
    messagesPerHour: Math.round((messages.length / hours) * 100) / 100,
  };
}

export function formatStatsForTelegram(stats: MeshStats): string {
  return [
    "📊 <b>Mesh Stats</b>",
    `Total: ${stats.totalMessages} messages`,
    `📢 Channel: ${stats.channelCount} | 🔒 DM: ${stats.dmCount}`,
    `👥 Nodes: ${stats.uniqueNodes.length}`,
    `📈 Rate: ${stats.messagesPerHour} msg/h`,
  ].join("\n");
}
