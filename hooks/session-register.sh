#!/bin/bash
# Hook: SessionStart — registers active session in tracking directory
# Wired to: hooks.SessionStart in ~/.claude/settings.json

source "$(dirname "$0")/utils.sh"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path')
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"')
MODEL=$(echo "$INPUT" | jq -r '.model // "unknown"')

TRACKING_DIR="$HOME/.claude/session-tracking"
mkdir -p "$TRACKING_DIR"

# PPID = Claude Code process (parent of this hook script)
CC_PID=$PPID

OUTFILE="$TRACKING_DIR/$SESSION_ID.json"


jq -n \
  --arg sid "$SESSION_ID" \
  --arg pid "$CC_PID" \
  --arg cwd "$CWD" \
  --arg transcript "$TRANSCRIPT" \
  --arg source "$SOURCE" \
  --arg model "$MODEL" \
  --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    session_id: $sid,
    pid: ($pid | tonumber),
    cwd: $cwd,
    transcript: $transcript,
    source: $source,
    model: $model,
    started_at: $started,
    ended_at: null,
    status: "active"
  }' > "$(_path "$OUTFILE")"

# --- Tab concurrency tracking ---
ACTIVE_TABS=$(_count_active_sessions "$TRACKING_DIR")
TELE_DIR="$HOME/.claude/input-telemetry"; mkdir -p "$TELE_DIR"
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg ev "open" --arg sid "$SESSION_ID" \
  --argjson tabs "$ACTIVE_TABS" '{ts:$ts,event:$ev,session_id:$sid,active_tabs:$tabs}' \
  >> "$(_path "$TELE_DIR/concurrency.jsonl")"

exit 0
