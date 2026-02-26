#!/bin/bash
# Hook: UserPromptSubmit — captures input telemetry
# Appends one JSONL line per user message. Must be fast and silent.
# Wired to: hooks.UserPromptSubmit in ~/.claude/settings.json

source "$(dirname "$0")/utils.sh"
INPUT=$(cat)

# Extract fields
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Skip empty prompts (slash commands, accidental enters)
if [ -z "$PROMPT" ] || [ "$PROMPT" = "null" ]; then
  exit 0
fi


# Compute metrics
CHAR_COUNT=${#PROMPT}
WORD_COUNT=$(echo "$PROMPT" | wc -w | tr -d ' ')
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Infer project from cwd: look for projects/<slug>/ pattern
PROJECT="unknown"
if [[ "$CWD" =~ projects/([^/]+) ]]; then
  PROJECT="${BASH_REMATCH[1]}"
fi

# Ensure data directory exists
DATA_DIR="$HOME/.claude/input-telemetry"
mkdir -p "$DATA_DIR"

RAW_FILE="$DATA_DIR/raw.jsonl"

# Append — single jq call, one line
jq -nc \
  --arg ts "$NOW" \
  --arg session_id "$SESSION_ID" \
  --arg project "$PROJECT" \
  --arg text "$PROMPT" \
  --argjson word_count "$WORD_COUNT" \
  --argjson char_count "$CHAR_COUNT" \
  '{ts: $ts, session_id: $session_id, project: $project, text: $text, word_count: $word_count, char_count: $char_count}' \
  >> "$(_path "$RAW_FILE")"

# Must exit 0 with no stdout to avoid interfering with prompt processing
exit 0
