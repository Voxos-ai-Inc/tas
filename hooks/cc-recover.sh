#!/bin/bash
# Claude Code session recovery utility
# Usage: cc-recover.sh [list|launch <session_id>|launch-all <id1> <id2> ...|clean <id1> <id2> ...]

source "$(dirname "$0")/utils.sh"
TRACKING_DIR="$HOME/.claude/session-tracking"
shopt -s nullglob



# Get transcript last-modified epoch, or 0 if missing
transcript_epoch() {
  local transcript="$1"
  if [ -f "$transcript" ]; then
    _stat_mtime "$transcript"
  else
    echo "0"
  fi
}

# Get transcript size in bytes, or 0 if missing
transcript_size() {
  local transcript="$1"
  if [ -f "$transcript" ]; then
    _stat_size "$transcript"
  else
    echo "0"
  fi
}

human_size() {
  local bytes=$1
  if [ "$bytes" -ge 1048576 ]; then
    echo "$((bytes / 1048576))MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$((bytes / 1024))KB"
  else
    echo "${bytes}B"
  fi
}

cmd_list() {
  # Output JSON array of orphaned sessions with enriched metadata
  local files=("$TRACKING_DIR"/*.json)
  local results="[]"

  for f in "${files[@]}"; do
    [ ! -f "$f" ] && continue

    local status
    status=$(_jqf -r '.status' "$f")
    [ "$status" != "active" ] && continue

    local pid
    pid=$(_jqf -r '.pid' "$f")
    # Session is orphaned if PID is dead
    if ! kill -0 "$pid" 2>/dev/null; then
      local transcript
      transcript=$(_jqf -r '.transcript' "$f")
      # Convert Windows path to Unix for stat if needed
      local transcript_unix
      transcript_unix=$(command -v cygpath >/dev/null 2>&1 && cygpath -u "$transcript" 2>/dev/null || echo "$transcript")

      local epoch size
      epoch=$(transcript_epoch "$transcript_unix")
      size=$(transcript_size "$transcript_unix")
      local hsize
      hsize=$(human_size "$size")

      # Enrich the session JSON with transcript metadata
      results=$(echo "$results" | jq --argjson session "$(_jqf '.' "$f")" \
        --arg last_active_epoch "$epoch" \
        --arg transcript_bytes "$size" \
        --arg transcript_human "$hsize" \
        '. + [$session + {last_active_epoch: ($last_active_epoch | tonumber), transcript_bytes: ($transcript_bytes | tonumber), transcript_human: $transcript_human}]')
    fi
  done

  # Sort by last_active_epoch descending (most recent first)
  echo "$results" | jq 'sort_by(-.last_active_epoch)'
}

cmd_launch() {
  local session_id="$1"
  if [ -z "$session_id" ]; then
    echo "Error: session_id required"
    exit 1
  fi

  # Attempt to launch in a new terminal tab
  if command -v wt >/dev/null 2>&1; then
    # Windows Terminal
    wt -w 0 nt --title "resume-${session_id:0:8}" claude --resume "$session_id"
  elif command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal --tab -- claude --resume "$session_id"
  elif command -v open >/dev/null 2>&1; then
    # macOS
    osascript -e "tell application \"Terminal\" to do script \"claude --resume $session_id\""
  else
    echo "Cannot auto-launch terminal. Run manually: claude --resume $session_id"
    return
  fi

  echo "Launched tab for session ${session_id:0:8}"
}

cmd_launch_all() {
  local count=0
  for session_id in "$@"; do
    cmd_launch "$session_id"
    count=$((count + 1))
    # Small delay between launches to avoid overwhelming terminal
    sleep 0.5
  done
  echo "Launched $count session(s)"
}

cmd_clean() {
  # Mark specified sessions as ended (so they don't appear as orphans)
  local count=0
  for session_id in "$@"; do
    local f="$TRACKING_DIR/${session_id}.json"
    if [ -f "$f" ]; then
      local now
      now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      local tmp
      tmp=$(_jqf --arg now "$now" '.status = "ended" | .ended_at = $now | .end_reason = "recovered-dismissed"' "$f")
      echo "$tmp" > "$f"
      count=$((count + 1))
    fi
  done
  echo "Cleaned $count session(s)"
}

case "${1:-list}" in
  list) cmd_list ;;
  launch) shift; cmd_launch "$@" ;;
  launch-all) shift; cmd_launch_all "$@" ;;
  clean) shift; cmd_clean "$@" ;;
  *) echo "Usage: $0 [list|launch <id>|launch-all <id...>|clean <id...>]"; exit 1 ;;
esac
