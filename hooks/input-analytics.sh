#!/bin/bash
# Input telemetry analytics CLI
# Usage: input-analytics.sh {summary|project <slug>|recent [N]|trends|dimensions|tabs}

set -euo pipefail

DATA_DIR="$HOME/.claude/input-telemetry"
RAW_FILE="$DATA_DIR/raw.jsonl"
ANALYZED_FILE="$DATA_DIR/analyzed.jsonl"
CONCURRENCY_FILE="$DATA_DIR/concurrency.jsonl"

# Cross-platform path conversion
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }

require_file() {
  local f="$1" label="$2"
  if [ ! -f "$f" ] || [ ! -s "$f" ]; then
    echo "No $label data found at $f" >&2
    exit 0
  fi
}

CMD="${1:-}"
shift || true

case "$CMD" in
  summary)
    require_file "$RAW_FILE" "raw telemetry"
    WIN_RF="$(_path "$RAW_FILE")"

    echo "=== Input Telemetry Summary ==="
    jq -s '
      {
        total_messages: length,
        total_words: ([.[].word_count] | add // 0),
        total_chars: ([.[].char_count] | add // 0),
        avg_words: (([.[].word_count] | add // 0) / (length | if . == 0 then 1 else . end) | round),
        sessions: ([.[].session_id] | unique | length),
        projects: ([.[].project] | unique | sort),
        date_range: {
          first: (sort_by(.ts) | first.ts // "?"),
          last: (sort_by(.ts) | last.ts // "?")
        }
      }
    ' "$WIN_RF" | jq -r '
      "Messages:    \(.total_messages)",
      "Sessions:    \(.sessions)",
      "Total words: \(.total_words)",
      "Total chars: \(.total_chars)",
      "Avg words:   \(.avg_words)",
      "Projects:    \(.projects | join(", "))",
      "Date range:  \(.date_range.first[:10]) to \(.date_range.last[:10])"
    '

    # If analyzed data exists, show coverage
    if [ -f "$ANALYZED_FILE" ] && [ -s "$ANALYZED_FILE" ]; then
      WIN_AF="$(_path "$ANALYZED_FILE")"
      ANALYZED_COUNT=$(jq -s 'length' "$WIN_AF")
      RAW_COUNT=$(jq -s 'length' "$WIN_RF")
      echo "Analyzed:    $ANALYZED_COUNT / $RAW_COUNT messages"
    fi

    # If concurrency data exists, show tab stats
    if [ -f "$CONCURRENCY_FILE" ] && [ -s "$CONCURRENCY_FILE" ]; then
      WIN_CF="$(_path "$CONCURRENCY_FILE")"
      jq -s '
        {
          peak_tabs: ([.[].active_tabs] | max),
          avg_tabs: (([.[].active_tabs] | add) / length | . * 10 | round / 10),
          events: length
        }
      ' "$WIN_CF" | jq -r '
        "Peak tabs:   \(.peak_tabs)",
        "Avg tabs:    \(.avg_tabs)",
        "Tab events:  \(.events)"
      '
    fi
    ;;

  project)
    PROJECT="${1:?project slug required}"
    require_file "$RAW_FILE" "raw telemetry"
    WIN_RF="$(_path "$RAW_FILE")"

    echo "=== Project: $PROJECT ==="
    jq -s --arg p "$PROJECT" '
      [.[] | select(.project == $p)] |
      if length == 0 then {messages: 0}
      else {
        messages: length,
        sessions: ([.[].session_id] | unique | length),
        total_words: ([.[].word_count] | add),
        avg_words: (([.[].word_count] | add) / length | round)
      } end
    ' "$WIN_RF" | jq -r '
      if .messages == 0 then "No messages found for this project."
      else
        "Messages:    \(.messages)",
        "Sessions:    \(.sessions)",
        "Total words: \(.total_words)",
        "Avg words:   \(.avg_words)"
      end
    '

    # If analyzed data exists, show intent breakdown
    if [ -f "$ANALYZED_FILE" ] && [ -s "$ANALYZED_FILE" ]; then
      WIN_AF="$(_path "$ANALYZED_FILE")"
      HAS_DATA=$(jq -s --arg p "$PROJECT" '[.[] | select(.project == $p)] | length' "$WIN_AF")
      if [ "$HAS_DATA" -gt 0 ]; then
        echo ""
        echo "--- Intent Distribution ---"
        printf "%-12s  %5s\n" "INTENT" "COUNT"
        printf "%-12s  %5s\n" "------------" "-----"
        jq -s --arg p "$PROJECT" '
          [.[] | select(.project == $p)] | group_by(.intent) |
          map({intent: .[0].intent, count: length}) | sort_by(-.count) | .[]
        ' "$WIN_AF" | jq -r '"\(.intent)\t\(.count)"' | while IFS=$'\t' read -r intent count; do
          printf "%-12s  %5s\n" "$intent" "$count"
        done

        echo ""
        echo "--- Avg Specificity & Complexity ---"
        jq -s --arg p "$PROJECT" '
          [.[] | select(.project == $p)] |
          {
            avg_specificity: (([.[].specificity] | add) / length | . * 10 | round / 10),
            avg_complexity: (([.[].complexity] | add) / length | . * 10 | round / 10)
          }
        ' "$WIN_AF" | jq -r '"Avg specificity: \(.avg_specificity)", "Avg complexity:  \(.avg_complexity)"'
      fi
    fi
    ;;

  recent)
    LIMIT="${1:-10}"
    require_file "$RAW_FILE" "raw telemetry"
    WIN_RF="$(_path "$RAW_FILE")"

    echo "=== Last $LIMIT Messages ==="
    printf "%-20s  %-10s  %5s  %s\n" "TIMESTAMP" "PROJECT" "WORDS" "TEXT (truncated)"
    printf "%-20s  %-10s  %5s  %s\n" "--------------------" "----------" "-----" "----------------"
    jq -s "sort_by(.ts) | reverse | .[:$LIMIT] | reverse | .[]" "$WIN_RF" | jq -r '
      [
        .ts[:19],
        .project,
        (.word_count | tostring),
        (.text[:60] | gsub("\n"; " "))
      ] | @tsv
    ' | while IFS=$'\t' read -r ts proj wc text; do
      printf "%-20s  %-10s  %5s  %s\n" "$ts" "$proj" "$wc" "$text"
    done
    ;;

  trends)
    require_file "$RAW_FILE" "raw telemetry"
    WIN_RF="$(_path "$RAW_FILE")"

    echo "=== Daily Trends ==="
    printf "%-12s  %5s  %7s  %7s\n" "DATE" "MSGS" "WORDS" "AVG_WC"
    printf "%-12s  %5s  %7s  %7s\n" "------------" "-----" "-------" "-------"
    jq -s '
      group_by(.ts[:10]) |
      map({
        date: .[0].ts[:10],
        msgs: length,
        words: ([.[].word_count] | add),
        avg_wc: (([.[].word_count] | add) / length | round)
      }) | sort_by(.date) | .[]
    ' "$WIN_RF" | jq -r '[.date, (.msgs | tostring), (.words | tostring), (.avg_wc | tostring)] | @tsv' | while IFS=$'\t' read -r date msgs words avg; do
      printf "%-12s  %5s  %7s  %7s\n" "$date" "$msgs" "$words" "$avg"
    done
    ;;

  dimensions)
    require_file "$ANALYZED_FILE" "analyzed telemetry"
    WIN_AF="$(_path "$ANALYZED_FILE")"

    echo "=== Dimension Analysis ==="

    echo ""
    echo "--- Intent Distribution ---"
    printf "%-12s  %5s  %5s\n" "INTENT" "COUNT" "PCT"
    printf "%-12s  %5s  %5s\n" "------------" "-----" "-----"
    jq -s '
      (length) as $total |
      group_by(.intent) |
      map({intent: .[0].intent, count: length, pct: (length / $total * 100 | round)}) |
      sort_by(-.count) | .[]
    ' "$WIN_AF" | jq -r '"\(.intent)\t\(.count)\t\(.pct)%"' | while IFS=$'\t' read -r intent count pct; do
      printf "%-12s  %5s  %5s\n" "$intent" "$count" "$pct"
    done

    echo ""
    echo "--- Avg Specificity & Complexity by Intent ---"
    printf "%-12s  %5s  %5s\n" "INTENT" "SPEC" "CMPLX"
    printf "%-12s  %5s  %5s\n" "------------" "-----" "-----"
    jq -s '
      group_by(.intent) |
      map({
        intent: .[0].intent,
        avg_spec: (([.[].specificity] | add) / length | . * 10 | round / 10),
        avg_cmplx: (([.[].complexity] | add) / length | . * 10 | round / 10)
      }) | sort_by(-.avg_cmplx) | .[]
    ' "$WIN_AF" | jq -r '"\(.intent)\t\(.avg_spec)\t\(.avg_cmplx)"' | while IFS=$'\t' read -r intent spec cmplx; do
      printf "%-12s  %5s  %5s\n" "$intent" "$spec" "$cmplx"
    done

    echo ""
    echo "--- Tone Distribution ---"
    printf "%-14s  %5s  %5s\n" "TONE" "COUNT" "PCT"
    printf "%-14s  %5s  %5s\n" "--------------" "-----" "-----"
    jq -s '
      (length) as $total |
      group_by(.tone) |
      map({tone: .[0].tone, count: length, pct: (length / $total * 100 | round)}) |
      sort_by(-.count) | .[]
    ' "$WIN_AF" | jq -r '"\(.tone)\t\(.count)\t\(.pct)%"' | while IFS=$'\t' read -r tone count pct; do
      printf "%-14s  %5s  %5s\n" "$tone" "$count" "$pct"
    done
    ;;

  tabs)
    require_file "$CONCURRENCY_FILE" "concurrency telemetry"
    WIN_CF="$(_path "$CONCURRENCY_FILE")"

    echo "=== Tab Concurrency ==="

    # Overall stats
    jq -s '
      {
        total_events: length,
        opens: ([.[] | select(.event == "open")] | length),
        closes: ([.[] | select(.event == "close")] | length),
        peak_tabs: ([.[].active_tabs] | max),
        avg_tabs: (([.[].active_tabs] | add) / length | . * 10 | round / 10),
        current_tabs: (sort_by(.ts) | last.active_tabs)
      }
    ' "$WIN_CF" | jq -r '
      "Total events: \(.total_events)",
      "Opens:        \(.opens)",
      "Closes:       \(.closes)",
      "Peak tabs:    \(.peak_tabs)",
      "Avg tabs:     \(.avg_tabs)",
      "Current tabs: \(.current_tabs)"
    '

    echo ""
    echo "--- Timeline (last 20 events) ---"
    printf "%-20s  %-6s  %4s\n" "TIMESTAMP" "EVENT" "TABS"
    printf "%-20s  %-6s  %4s\n" "--------------------" "------" "----"
    jq -s 'sort_by(.ts) | reverse | .[:20] | reverse | .[]' "$WIN_CF" | jq -r '
      "\(.ts[:19])\t\(.event)\t\(.active_tabs)"
    ' | while IFS=$'\t' read -r ts event tabs; do
      printf "%-20s  %-6s  %4s\n" "$ts" "$event" "$tabs"
    done

    # Daily breakdown
    echo ""
    echo "--- Daily Peak Tabs ---"
    printf "%-12s  %4s  %6s\n" "DATE" "PEAK" "EVENTS"
    printf "%-12s  %4s  %6s\n" "------------" "----" "------"
    jq -s '
      group_by(.ts[:10]) |
      map({
        date: .[0].ts[:10],
        peak: ([.[].active_tabs] | max),
        events: length
      }) | sort_by(.date) | .[]
    ' "$WIN_CF" | jq -r '"\(.date)\t\(.peak)\t\(.events)"' | while IFS=$'\t' read -r date peak events; do
      printf "%-12s  %4s  %6s\n" "$date" "$peak" "$events"
    done
    ;;

  *)
    echo "Usage: input-analytics.sh {summary|project <slug>|recent [N]|trends|dimensions|tabs}"
    echo ""
    echo "Commands:"
    echo "  summary          Total messages, words, sessions, projects, tab stats"
    echo "  project <slug>   Messages + intent breakdown for a project"
    echo "  recent [N]       Last N messages (default: 10)"
    echo "  trends           Daily message count + word volume"
    echo "  dimensions       Intent, specificity, complexity, tone distributions"
    echo "  tabs             Tab concurrency timeline, peak/avg/current"
    exit 1
    ;;
esac
