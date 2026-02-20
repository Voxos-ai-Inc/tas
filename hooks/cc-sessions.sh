#!/bin/bash
# Claude Code session tracking utility
# Usage: cc-sessions.sh [check|list|clean]

TRACKING_DIR="$HOME/.claude/session-tracking"
shopt -s nullglob

# Cross-platform jq wrapper: converts paths for Windows/MSYS if needed
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }
jqf() {
  local file="${@: -1}"
  local args=("${@:1:$#-1}")
  jq "${args[@]}" "$(_path "$file")"
}

cmd_check() {
  local found=0
  local results=""
  local files=("$TRACKING_DIR"/*.json)

  for f in "${files[@]}"; do
    [ ! -f "$f" ] && continue
    local status
    status=$(jqf -r '.status' "$f")
    [ "$status" != "active" ] && continue

    local pid
    pid=$(jqf -r '.pid' "$f")
    if ! kill -0 "$pid" 2>/dev/null; then
      found=$((found + 1))
      results+="$(jqf -r '
        "  Session: \(.session_id)\n" +
        "  CWD:     \(.cwd)\n" +
        "  Model:   \(.model)\n" +
        "  Started: \(.started_at)\n" +
        "  Source:   \(.source)\n" +
        "  Resume:  claude --resume \(.session_id)\n"
      ' "$f")"
      results+=$'\n'
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "No orphaned sessions."
  else
    echo "Found $found orphaned session(s):"
    echo ""
    echo -e "$results"
  fi
}

cmd_list() {
  echo "All tracked sessions:"
  echo ""
  local files=("$TRACKING_DIR"/*.json)

  for f in "${files[@]}"; do
    [ ! -f "$f" ] && continue
    local pid
    pid=$(jqf -r '.pid' "$f")
    local alive="dead"
    kill -0 "$pid" 2>/dev/null && alive="alive"

    jqf -r --arg alive "$alive" '
      "\(.status | if . == "active" then "●" else "○" end) \(.session_id[0:8])  \(.model | .[0:12])  \(.started_at)  pid=\(.pid)(\($alive))  \(.cwd)"
    ' "$f"
  done
}

cmd_clean() {
  local count=0
  local files=("$TRACKING_DIR"/*.json)

  # Remove ended sessions
  for f in "${files[@]}"; do
    [ ! -f "$f" ] && continue
    local status
    status=$(jqf -r '.status' "$f")
    if [ "$status" = "ended" ]; then
      rm "$f"
      count=$((count + 1))
    fi
  done

  # Refresh file list after deletions
  files=("$TRACKING_DIR"/*.json)

  # Remove active sessions whose PID is dead (orphans)
  for f in "${files[@]}"; do
    [ ! -f "$f" ] && continue
    local status
    status=$(jqf -r '.status' "$f")
    [ "$status" != "active" ] && continue
    local pid
    pid=$(jqf -r '.pid' "$f")
    if ! kill -0 "$pid" 2>/dev/null; then
      rm "$f"
      count=$((count + 1))
    fi
  done

  echo "Cleaned $count session(s)."
}

case "${1:-check}" in
  check) cmd_check ;;
  list) cmd_list ;;
  clean) cmd_clean ;;
  *) echo "Usage: $0 [check|list|clean]"; exit 1 ;;
esac
