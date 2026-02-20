#!/bin/bash
# Hook: SessionStart — registers active session in tracking directory
# Wired to: hooks.SessionStart in ~/.claude/settings.json

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

# Cross-platform: cygpath for Windows/MSYS, passthrough otherwise
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }

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

exit 0
