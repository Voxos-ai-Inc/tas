#!/bin/bash
# Stop hook: nudges Claude to log tasks if none were recorded for this session.
# Blocks once per session (temp marker file). Second attempt always passes.
# Wired to: hooks.Stop in ~/.claude/settings.json

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

TRACKING_DIR="$HOME/.claude/task-tracking"
TASKS_FILE="$TRACKING_DIR/tasks.jsonl"
NUDGE_MARKER="/tmp/.nudged_${SESSION_ID}"

# Cross-platform: cygpath for Windows/MSYS, passthrough otherwise
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }

# If already nudged once this session, allow through
if [ -f "$NUDGE_MARKER" ]; then
  echo '{}'
  exit 0
fi

# Check if any tasks were logged for this session
TASK_COUNT=0
if [ -f "$TASKS_FILE" ]; then
  TASK_COUNT=$(jq -r --arg sid "$SESSION_ID" 'select(.session_id == $sid and .event == "estimate")' "$(_path "$TASKS_FILE")" 2>/dev/null | jq -s 'length')
fi

if [ "$TASK_COUNT" -gt 0 ]; then
  echo '{}'
  exit 0
fi

# No tasks logged — nudge once
touch "$NUDGE_MARKER"
jq -nc '{
  continue: true,
  stopReason: "No tasks logged for this session. Please log your work with task-log.sh or acknowledge this was a trivial/exploratory session. Then stop again."
}'
exit 0
