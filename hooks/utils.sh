#!/bin/bash
# Shared utilities for TAS hooks and scripts.
# Source this file: source "$(dirname "$0")/utils.sh"

# Cross-platform path conversion: cygpath for Windows/MSYS, passthrough otherwise
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }

# Cross-platform jq file wrapper: converts paths for Windows/MSYS if needed
_jqf() {
  local file="${*: -1}"
  local args=("${@:1:$#-1}")
  jq "${args[@]}" "$(_path "$file")"
}

# Cross-platform epoch from ISO 8601 date string
# GNU date uses `date -d`, BSD/macOS uses `date -jf`
_date_epoch() {
  local datestr="$1"
  date -d "$datestr" +%s 2>/dev/null \
    || date -jf "%Y-%m-%dT%H:%M:%SZ" "$datestr" +%s 2>/dev/null \
    || echo 0
}

# Cross-platform file modification time (epoch seconds)
# GNU stat uses -c %Y, BSD/macOS uses -f %m
_stat_mtime() {
  local file="$1"
  stat -c %Y "$file" 2>/dev/null \
    || stat -f %m "$file" 2>/dev/null \
    || echo 0
}

# Cross-platform file size in bytes
# GNU stat uses -c %s, BSD/macOS uses -f %z
_stat_size() {
  local file="$1"
  stat -c %s "$file" 2>/dev/null \
    || stat -f %z "$file" 2>/dev/null \
    || echo 0
}

# Cross-platform readlink -f (canonical path)
# GNU has readlink -f, BSD/macOS does not (needs manual resolution or realpath)
_readlink_f() {
  readlink -f "$1" 2>/dev/null \
    || realpath "$1" 2>/dev/null \
    || echo "$1"
}

# Count active sessions without grep -rl (which behaves differently across platforms)
_count_active_sessions() {
  local dir="$1"
  local count=0
  for f in "$dir"/*.json; do
    [ ! -f "$f" ] && continue
    if jq -e '.status == "active"' "$(_path "$f")" >/dev/null 2>&1; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}
