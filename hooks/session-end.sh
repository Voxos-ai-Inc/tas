#!/bin/bash
# Hook: SessionEnd — marks session as ended, parses transcript, writes summary
# Wired to: hooks.SessionEnd in ~/.claude/settings.json

source "$(dirname "$0")/utils.sh"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
REASON=$(echo "$INPUT" | jq -r '.reason // "unknown"')


SESSION_FILE="$HOME/.claude/session-tracking/$SESSION_ID.json"

# --- Phase 1: Mark session as ended ---
if [ -f "$SESSION_FILE" ]; then
  ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TMP_FILE="${SESSION_FILE}.tmp"
  jq --arg reason "$REASON" --arg ended_at "$ENDED_AT" \
    '.ended_at = $ended_at | .status = "ended" | .end_reason = $reason' \
    "$(_path "$SESSION_FILE")" > "$(_path "$TMP_FILE")" && mv "$TMP_FILE" "$SESSION_FILE"
fi

# --- Phase 1b: Tab concurrency tracking ---
ACTIVE_TABS=$(_count_active_sessions "$HOME/.claude/session-tracking")
TELE_DIR="$HOME/.claude/input-telemetry"; mkdir -p "$TELE_DIR"
ENDED_AT="${ENDED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
jq -nc --arg ts "$ENDED_AT" --arg ev "close" --arg sid "$SESSION_ID" \
  --argjson tabs "$ACTIVE_TABS" '{ts:$ts,event:$ev,session_id:$sid,active_tabs:$tabs}' \
  >> "$(_path "$TELE_DIR/concurrency.jsonl")"

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

  # Single-pass extraction: bytes, real token counts, model, tool counts, projects
  PARSE_RESULT=$(jq -s '
    {
      assistant_bytes: ([.[] | select(.type == "assistant") | (.message // "" | tostring | length)] | add // 0),
      user_bytes: ([.[] | select(.type == "user") | (.message // "" | tostring | length)] | add // 0),
      turn_count: ([.[] | select(.type == "assistant")] | length),
      compact_count: ([.[] | select(.subtype == "compact_boundary")] | length),
      compact_pre_tokens: [.[] | select(.subtype == "compact_boundary") | (.num_tokens_truncated // 0)],
      output_tokens: ([.[] | select(.type == "assistant") | .message.usage.output_tokens // 0] | add // 0),
      input_tokens: ([.[] | select(.type == "assistant") | .message.usage.input_tokens // 0] | add // 0),
      cache_creation_tokens: ([.[] | select(.type == "assistant") | .message.usage.cache_creation_input_tokens // 0] | add // 0),
      cache_read_tokens: ([.[] | select(.type == "assistant") | .message.usage.cache_read_input_tokens // 0] | add // 0),
      model: (([.[] | select(.type == "assistant") | .message.model // empty] | first) // "unknown"),
      tool_counts: ([.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name] | group_by(.) | map({(.[0]): length}) | add // {}),
      inferred_projects: ([.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input | (.file_path // .path // .command // "") | capture("projects/(?<p>[^/]+)/") | .p] | unique)
    }
  ' "$(_path "$TRANSCRIPT_PATH")" 2>/dev/null || echo '{}')

  if [ -n "$PARSE_RESULT" ] && [ "$PARSE_RESULT" != "{}" ]; then
    ASSISTANT_BYTES=$(echo "$PARSE_RESULT" | jq -r '.assistant_bytes // 0')
    USER_BYTES=$(echo "$PARSE_RESULT" | jq -r '.user_bytes // 0')
    TURN_COUNT=$(echo "$PARSE_RESULT" | jq -r '.turn_count // 0')
    COMPACT_COUNT=$(echo "$PARSE_RESULT" | jq -r '.compact_count // 0')
    COMPACT_PRE_TOKENS=$(echo "$PARSE_RESULT" | jq -c '.compact_pre_tokens // []')
    OUTPUT_TOKENS=$(echo "$PARSE_RESULT" | jq -r '.output_tokens // 0')
    INPUT_TOKENS=$(echo "$PARSE_RESULT" | jq -r '.input_tokens // 0')
    CACHE_CREATION_TOKENS=$(echo "$PARSE_RESULT" | jq -r '.cache_creation_tokens // 0')
    CACHE_READ_TOKENS=$(echo "$PARSE_RESULT" | jq -r '.cache_read_tokens // 0')
    TRANSCRIPT_MODEL=$(echo "$PARSE_RESULT" | jq -r '.model // "unknown"')
    TOOL_COUNTS=$(echo "$PARSE_RESULT" | jq -c '.tool_counts // {}')
    INFERRED_PROJECTS=$(echo "$PARSE_RESULT" | jq -c '.inferred_projects // []')
  fi
fi

# Use model from transcript if available, fall back to hook input
if [ -n "$TRANSCRIPT_MODEL" ] && [ "$TRANSCRIPT_MODEL" != "unknown" ]; then
  MODEL="$TRANSCRIPT_MODEL"
fi

# Token fields default to 0
OUTPUT_TOKENS="${OUTPUT_TOKENS:-0}"
INPUT_TOKENS="${INPUT_TOKENS:-0}"
CACHE_CREATION_TOKENS="${CACHE_CREATION_TOKENS:-0}"
CACHE_READ_TOKENS="${CACHE_READ_TOKENS:-0}"
TOOL_COUNTS="${TOOL_COUNTS:-{}}"
INFERRED_PROJECTS="${INFERRED_PROJECTS:-[]}"
TRANSCRIPT_MODEL="${TRANSCRIPT_MODEL:-unknown}"

# Compute estimated API cost (USD per 1M tokens)
# Default rates: Sonnet input=$3, output=$15. Adjust for your model.
# Opus: input=$15, output=$75. Haiku: input=$0.80, output=$4.
# Cache: creation ~1.25x input, read ~0.1x input.
ESTIMATED_COST=$(echo "$INPUT_TOKENS $OUTPUT_TOKENS $CACHE_CREATION_TOKENS $CACHE_READ_TOKENS" | awk '{
  cost = ($1 * 3 + $2 * 15 + $3 * 3.75 + $4 * 0.30) / 1000000
  printf "%.2f", cost
}')

# Compute duration in minutes
DURATION_MINUTES=0
if [ -n "$STARTED_AT" ] && [ -n "$ENDED_AT" ]; then
  START_EPOCH=$(_date_epoch "$STARTED_AT")
  END_EPOCH=$(_date_epoch "$ENDED_AT")
  if [ "$START_EPOCH" -gt 0 ] && [ "$END_EPOCH" -gt 0 ]; then
    DURATION_MINUTES=$(( (END_EPOCH - START_EPOCH) / 60 ))
  fi
fi

# Count tasks and projects from tasks.jsonl, merge with inferred projects
TASK_COUNT=0
TASK_PROJECTS="[]"
if [ -f "$TASKS_FILE" ]; then
  TASK_COUNT=$(jq -r --arg sid "$SESSION_ID" 'select(.session_id == $sid and .event == "estimate")' "$(_path "$TASKS_FILE")" 2>/dev/null | jq -s 'length')
  TASK_PROJECTS=$(jq -r --arg sid "$SESSION_ID" 'select(.session_id == $sid and .event == "estimate") | .project' "$(_path "$TASKS_FILE")" 2>/dev/null | jq -Rs 'split("\n") | map(select(length > 0)) | unique')
fi

# Merge task-logged projects with transcript-inferred projects
PROJECTS_TOUCHED=$(echo "$TASK_PROJECTS" "$INFERRED_PROJECTS" | jq -sc 'add | unique')

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
  --argjson output_tokens "$OUTPUT_TOKENS" \
  --argjson input_tokens "$INPUT_TOKENS" \
  --argjson cache_creation_tokens "$CACHE_CREATION_TOKENS" \
  --argjson cache_read_tokens "$CACHE_READ_TOKENS" \
  --argjson estimated_cost_usd "$ESTIMATED_COST" \
  --argjson turn_count "$TURN_COUNT" \
  --argjson compact_count "$COMPACT_COUNT" \
  --argjson compact_pre_tokens "$COMPACT_PRE_TOKENS" \
  --argjson tool_counts "$TOOL_COUNTS" \
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
    output_tokens: $output_tokens,
    input_tokens: $input_tokens,
    cache_creation_tokens: $cache_creation_tokens,
    cache_read_tokens: $cache_read_tokens,
    estimated_cost_usd: $estimated_cost_usd,
    turn_count: $turn_count,
    compact_count: $compact_count,
    compact_pre_tokens: $compact_pre_tokens,
    tool_counts: $tool_counts,
    task_count: $task_count,
    projects_touched: $projects_touched,
    cwd: $cwd
  }' >> "$(_path "$SESSIONS_FILE")"


exit 0
