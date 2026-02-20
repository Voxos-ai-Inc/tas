#!/bin/bash
# Hook: SessionEnd — marks session as ended, parses transcript, writes summary
# Wired to: hooks.SessionEnd in ~/.claude/settings.json

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
REASON=$(echo "$INPUT" | jq -r '.reason // "unknown"')

# Cross-platform: cygpath for Windows/MSYS, passthrough otherwise
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }

SESSION_FILE="$HOME/.claude/session-tracking/$SESSION_ID.json"

# --- Phase 1: Mark session as ended ---
if [ -f "$SESSION_FILE" ]; then
  ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TMP_FILE="${SESSION_FILE}.tmp"
  jq --arg reason "$REASON" --arg ended_at "$ENDED_AT" \
    '.ended_at = $ended_at | .status = "ended" | .end_reason = $reason' \
    "$(_path "$SESSION_FILE")" > "$(_path "$TMP_FILE")" && mv "$TMP_FILE" "$SESSION_FILE"
fi

# --- Phase 2: Parse transcript and write session summary ---
TRACKING_DIR="$HOME/.claude/task-tracking"
mkdir -p "$TRACKING_DIR"
SESSIONS_FILE="$TRACKING_DIR/sessions.jsonl"
TASKS_FILE="$TRACKING_DIR/tasks.jsonl"

# Read session metadata
STARTED_AT=""
CWD=""
MODEL=""
TRANSCRIPT_PATH=""
if [ -f "$SESSION_FILE" ]; then
  STARTED_AT=$(jq -r '.started_at // ""' "$(_path "$SESSION_FILE")")
  CWD=$(jq -r '.cwd // ""' "$(_path "$SESSION_FILE")")
  MODEL=$(jq -r '.model // "unknown"' "$(_path "$SESSION_FILE")")
  TRANSCRIPT_PATH=$(jq -r '.transcript // ""' "$(_path "$SESSION_FILE")")
fi

ENDED_AT="${ENDED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

# Parse transcript if available
TRANSCRIPT_BYTES=0
ASSISTANT_BYTES=0
USER_BYTES=0
TURN_COUNT=0
COMPACT_COUNT=0
COMPACT_PRE_TOKENS="[]"

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TRANSCRIPT_BYTES=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)

  PARSE_RESULT=$(jq -s '
    {
      assistant_bytes: ([.[] | select(.type == "assistant") | (.message // "" | tostring | length)] | add // 0),
      user_bytes: ([.[] | select(.type == "human") | (.message // "" | tostring | length)] | add // 0),
      turn_count: ([.[] | select(.type == "assistant")] | length),
      compact_count: ([.[] | select(.type == "summary")] | length),
      compact_pre_tokens: [.[] | select(.type == "summary") | (.num_tokens_truncated // 0)]
    }
  ' "$(_path "$TRANSCRIPT_PATH")" 2>/dev/null || echo '{}')

  if [ -n "$PARSE_RESULT" ] && [ "$PARSE_RESULT" != "{}" ]; then
    ASSISTANT_BYTES=$(echo "$PARSE_RESULT" | jq -r '.assistant_bytes // 0')
    USER_BYTES=$(echo "$PARSE_RESULT" | jq -r '.user_bytes // 0')
    TURN_COUNT=$(echo "$PARSE_RESULT" | jq -r '.turn_count // 0')
    COMPACT_COUNT=$(echo "$PARSE_RESULT" | jq -r '.compact_count // 0')
    COMPACT_PRE_TOKENS=$(echo "$PARSE_RESULT" | jq -c '.compact_pre_tokens // []')
  fi
fi

# Estimate tokens (~4 chars per token)
EST_OUTPUT_TOKENS=$(( ASSISTANT_BYTES / 4 ))
EST_INPUT_TOKENS=$(( USER_BYTES / 4 ))

# Compute duration in minutes
DURATION_MINUTES=0
if [ -n "$STARTED_AT" ] && [ -n "$ENDED_AT" ]; then
  START_EPOCH=$(date -d "$STARTED_AT" +%s 2>/dev/null || echo 0)
  END_EPOCH=$(date -d "$ENDED_AT" +%s 2>/dev/null || echo 0)
  if [ "$START_EPOCH" -gt 0 ] && [ "$END_EPOCH" -gt 0 ]; then
    DURATION_MINUTES=$(( (END_EPOCH - START_EPOCH) / 60 ))
  fi
fi

# Count tasks and projects from tasks.jsonl
TASK_COUNT=0
PROJECTS_TOUCHED="[]"
if [ -f "$TASKS_FILE" ]; then
  TASK_COUNT=$(jq -r --arg sid "$SESSION_ID" 'select(.session_id == $sid and .event == "estimate")' "$(_path "$TASKS_FILE")" 2>/dev/null | jq -s 'length')
  PROJECTS_TOUCHED=$(jq -r --arg sid "$SESSION_ID" 'select(.session_id == $sid and .event == "estimate") | .project' "$(_path "$TASKS_FILE")" 2>/dev/null | jq -Rs 'split("\n") | map(select(length > 0)) | unique')
fi

# Append session summary
jq -nc \
  --arg session_id "$SESSION_ID" \
  --arg model "$MODEL" \
  --arg started_at "$STARTED_AT" \
  --arg ended_at "$ENDED_AT" \
  --argjson duration_minutes "$DURATION_MINUTES" \
  --argjson transcript_bytes "$TRANSCRIPT_BYTES" \
  --argjson assistant_bytes "$ASSISTANT_BYTES" \
  --argjson user_bytes "$USER_BYTES" \
  --argjson estimated_output_tokens "$EST_OUTPUT_TOKENS" \
  --argjson estimated_input_tokens "$EST_INPUT_TOKENS" \
  --argjson turn_count "$TURN_COUNT" \
  --argjson compact_count "$COMPACT_COUNT" \
  --argjson compact_pre_tokens "$COMPACT_PRE_TOKENS" \
  --argjson task_count "$TASK_COUNT" \
  --argjson projects_touched "$PROJECTS_TOUCHED" \
  --arg cwd "$CWD" \
  '{
    session_id: $session_id,
    model: $model,
    started_at: $started_at,
    ended_at: $ended_at,
    duration_minutes: $duration_minutes,
    transcript_bytes: $transcript_bytes,
    assistant_bytes: $assistant_bytes,
    user_bytes: $user_bytes,
    estimated_output_tokens: $estimated_output_tokens,
    estimated_input_tokens: $estimated_input_tokens,
    turn_count: $turn_count,
    compact_count: $compact_count,
    compact_pre_tokens: $compact_pre_tokens,
    task_count: $task_count,
    projects_touched: $projects_touched,
    cwd: $cwd
  }' >> "$(_path "$SESSIONS_FILE")"

exit 0
