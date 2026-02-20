#!/bin/bash
# Task event logger for token budgeting system
# Usage:
#   task-log.sh estimate <session_id> <project> <service> "<description>" <estimated_tokens>
#   task-log.sh start <session_id> <task_id>
#   task-log.sh complete <session_id> <task_id> <actual_tokens_est> <files_changed> [commit_hash]

set -euo pipefail

TRACKING_DIR="$HOME/.claude/task-tracking"
TASKS_FILE="$TRACKING_DIR/tasks.jsonl"
mkdir -p "$TRACKING_DIR"

# Cross-platform: cygpath for Windows/MSYS, passthrough otherwise
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }

CMD="${1:-}"
shift || true

case "$CMD" in
  estimate)
    SESSION_ID="${1:?session_id required}"
    PROJECT="${2:?project required}"
    SERVICE="${3:?service required}"
    DESCRIPTION="${4:?description required}"
    ESTIMATED_TOKENS="${5:?estimated_tokens required}"

    # Generate task_id: project-service-timestamp
    TASK_ID="${PROJECT}-${SERVICE}-$(date +%s)"
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq -nc \
      --arg event "estimate" \
      --arg session_id "$SESSION_ID" \
      --arg task_id "$TASK_ID" \
      --arg project "$PROJECT" \
      --arg service "$SERVICE" \
      --arg description "$DESCRIPTION" \
      --argjson estimated_tokens "$ESTIMATED_TOKENS" \
      --arg timestamp "$NOW" \
      '{event: $event, session_id: $session_id, task_id: $task_id, project: $project, service: $service, description: $description, estimated_tokens: $estimated_tokens, timestamp: $timestamp}' \
      >> "$(_path "$TASKS_FILE")"

    echo "$TASK_ID"
    ;;

  start)
    SESSION_ID="${1:?session_id required}"
    TASK_ID="${2:?task_id required}"
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq -nc \
      --arg event "start" \
      --arg session_id "$SESSION_ID" \
      --arg task_id "$TASK_ID" \
      --arg timestamp "$NOW" \
      '{event: $event, session_id: $session_id, task_id: $task_id, timestamp: $timestamp}' \
      >> "$(_path "$TASKS_FILE")"

    echo "started $TASK_ID"
    ;;

  complete)
    SESSION_ID="${1:?session_id required}"
    TASK_ID="${2:?task_id required}"
    ACTUAL_TOKENS="${3:?actual_tokens_est required}"
    FILES_CHANGED="${4:?files_changed required}"
    COMMIT_HASH="${5:-}"
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq -nc \
      --arg event "complete" \
      --arg session_id "$SESSION_ID" \
      --arg task_id "$TASK_ID" \
      --argjson actual_tokens "$ACTUAL_TOKENS" \
      --argjson files_changed "$FILES_CHANGED" \
      --arg commit_hash "$COMMIT_HASH" \
      --arg timestamp "$NOW" \
      '{event: $event, session_id: $session_id, task_id: $task_id, actual_tokens: $actual_tokens, files_changed: $files_changed, commit_hash: $commit_hash, timestamp: $timestamp}' \
      >> "$(_path "$TASKS_FILE")"

    echo "completed $TASK_ID"
    ;;

  *)
    echo "Usage: task-log.sh {estimate|start|complete} ..." >&2
    exit 1
    ;;
esac

exit 0
