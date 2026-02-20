#!/bin/bash
# Analytics CLI for token budgeting system
# Usage: cc-budget.sh {summary|sessions|projects|accuracy|daily} [args]

set -euo pipefail

TRACKING_DIR="$HOME/.claude/task-tracking"
TASKS_FILE="$TRACKING_DIR/tasks.jsonl"
SESSIONS_FILE="$TRACKING_DIR/sessions.jsonl"

# Cross-platform path conversion
_path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }

# Check file exists and has content
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
    require_file "$SESSIONS_FILE" "sessions"
    WIN_SF="$(_path "$SESSIONS_FILE")"
    TOTAL_TASKS=0
    if [ -f "$TASKS_FILE" ] && [ -s "$TASKS_FILE" ]; then
      WIN_TF="$(_path "$TASKS_FILE")"
      TOTAL_TASKS=$(jq -s '[.[] | select(.event == "estimate")] | length' "$WIN_TF")
    fi

    jq -s '
      {
        total_sessions: length,
        total_duration_hours: (([.[].duration_minutes] | add // 0) / 60 | . * 10 | round / 10),
        total_output_tokens: ([.[].estimated_output_tokens] | add // 0),
        total_input_tokens: ([.[].estimated_input_tokens] | add // 0),
        avg_output_tokens_per_session: (([.[].estimated_output_tokens] | add // 0) / (length | if . == 0 then 1 else . end) | round),
        avg_turns_per_session: (([.[].turn_count] | add // 0) / (length | if . == 0 then 1 else . end) | . * 10 | round / 10),
        total_compacts: ([.[].compact_count] | add // 0)
      }
    ' "$WIN_SF" | jq --argjson tasks "$TOTAL_TASKS" '. + {total_tasks: $tasks}' | jq -r '
      "=== Token Budget Summary ===",
      "Sessions:        \(.total_sessions)",
      "Total duration:  \(.total_duration_hours)h",
      "Output tokens:   \(.total_output_tokens | . / 1000 | . * 10 | round / 10)k",
      "Input tokens:    \(.total_input_tokens | . / 1000 | . * 10 | round / 10)k",
      "Avg output/sess: \(.avg_output_tokens_per_session | . / 1000 | . * 10 | round / 10)k",
      "Avg turns/sess:  \(.avg_turns_per_session)",
      "Total compacts:  \(.total_compacts)",
      "Total tasks:     \(.total_tasks)"
    '
    ;;

  sessions)
    require_file "$SESSIONS_FILE" "sessions"
    WIN_SF="$(_path "$SESSIONS_FILE")"
    LIMIT="${1:-10}"

    echo "=== Last $LIMIT Sessions ==="
    printf "%-12s  %5s  %8s  %5s  %s\n" "DATE" "MIN" "OUT_TOK" "TASKS" "PROJECTS"
    printf "%-12s  %5s  %8s  %5s  %s\n" "------------" "-----" "--------" "-----" "--------"

    jq -s "sort_by(.started_at) | reverse | .[:$LIMIT] | reverse | .[]" "$WIN_SF" | jq -r '
      [
        (.started_at[:10] // "?"),
        (.duration_minutes | tostring),
        ((.estimated_output_tokens / 1000 | . * 10 | round / 10 | tostring) + "k"),
        (.task_count | tostring),
        ((.projects_touched // []) | join(",") | if . == "" then "-" else . end)
      ] | @tsv
    ' | while IFS=$'\t' read -r date dur tok tasks projs; do
      printf "%-12s  %5s  %8s  %5s  %s\n" "$date" "$dur" "$tok" "$tasks" "$projs"
    done
    ;;

  projects)
    require_file "$TASKS_FILE" "tasks"
    WIN_TF="$(_path "$TASKS_FILE")"

    echo "=== Tokens by Project / Service ==="
    printf "%-15s  %-20s  %8s  %5s\n" "PROJECT" "SERVICE" "EST_TOK" "TASKS"
    printf "%-15s  %-20s  %8s  %5s\n" "---------------" "--------------------" "--------" "-----"

    jq -s '
      [.[] | select(.event == "estimate")]
      | group_by(.project)
      | [.[] | . as $grp | ($grp[0].project) as $p |
          ($grp | group_by(.service)) | .[] |
          {project: $p, service: .[0].service, est_tokens: ([.[].estimated_tokens] | add), count: length}
        ]
      | sort_by(.project)
      | .[]
    ' "$WIN_TF" | jq -r '[.project, .service, (.est_tokens | tostring), (.count | tostring)] | @tsv' | while IFS=$'\t' read -r proj svc tok cnt; do
      printf "%-15s  %-20s  %8s  %5s\n" "$proj" "$svc" "$tok" "$cnt"
    done
    ;;

  accuracy)
    require_file "$TASKS_FILE" "tasks"
    WIN_TF="$(_path "$TASKS_FILE")"

    echo "=== Estimation Accuracy ==="
    printf "%-30s  %8s  %8s  %6s\n" "TASK" "EST" "ACTUAL" "RATIO"
    printf "%-30s  %8s  %8s  %6s\n" "------------------------------" "--------" "--------" "------"

    jq -s '
      (
        [.[] | select(.event == "estimate")] | map({(.task_id): {description: .description, estimated: .estimated_tokens}}) | add // {}
      ) as $estimates |
      [.[] | select(.event == "complete")] |
      map(
        . as $c |
        ($estimates[$c.task_id] // null) |
        if . then {
          description: .description,
          estimated: .estimated,
          actual: $c.actual_tokens,
          ratio: (($c.actual_tokens / .estimated) * 100 | round / 100)
        } else empty end
      )
    ' "$WIN_TF" | jq -r '.[] | [
      (.description[:30]),
      (.estimated | tostring),
      (.actual | tostring),
      (.ratio | tostring)
    ] | @tsv' | while IFS=$'\t' read -r desc est act ratio; do
      printf "%-30s  %8s  %8s  %6s\n" "$desc" "$est" "$act" "$ratio"
    done

    echo ""
    echo "--- Calibration ---"
    jq -s '
      (
        [.[] | select(.event == "estimate")] | map({(.task_id): .estimated_tokens}) | add // {}
      ) as $est |
      [.[] | select(.event == "complete")] |
      map(($est[.task_id] // null) as $e | if $e then {est: $e, act: .actual_tokens} else empty end) |
      if length == 0 then {count: 0, avg_ratio: 0, overestimates: 0, underestimates: 0}
      else {
        count: length,
        avg_ratio: ([.[].act / .[].est] | add / length | . * 100 | round / 100),
        overestimates: ([.[] | select(.est > .act)] | length),
        underestimates: ([.[] | select(.act > .est)] | length),
        exact: ([.[] | select(.act == .est)] | length)
      } end
    ' "$WIN_TF" | jq -r '
      "Completed tasks: \(.count)",
      "Avg actual/est:  \(.avg_ratio)x",
      "Over-estimates:  \(.overestimates)",
      "Under-estimates: \(.underestimates)"
    '
    ;;

  daily)
    require_file "$SESSIONS_FILE" "sessions"
    WIN_SF="$(_path "$SESSIONS_FILE")"
    TARGET_DATE="${1:-$(date +%Y-%m-%d)}"

    echo "=== Daily Report: $TARGET_DATE ==="
    jq -s --arg d "$TARGET_DATE" '
      [.[] | select(.started_at[:10] == $d)] |
      if length == 0 then {sessions: 0}
      else {
        sessions: length,
        duration_minutes: ([.[].duration_minutes] | add),
        output_tokens: ([.[].estimated_output_tokens] | add),
        input_tokens: ([.[].estimated_input_tokens] | add),
        turns: ([.[].turn_count] | add),
        tasks: ([.[].task_count] | add),
        compacts: ([.[].compact_count] | add),
        projects: ([.[].projects_touched | .[]] | unique)
      } end
    ' "$WIN_SF" | jq -r '
      if .sessions == 0 then "No sessions found for this date."
      else
        "Sessions:       \(.sessions)",
        "Duration:       \(.duration_minutes)min",
        "Output tokens:  \(.output_tokens / 1000 | . * 10 | round / 10)k",
        "Input tokens:   \(.input_tokens / 1000 | . * 10 | round / 10)k",
        "Turns:          \(.turns)",
        "Tasks:          \(.tasks)",
        "Compacts:       \(.compacts)",
        "Projects:       \(.projects | join(", "))"
      end
    '
    ;;

  *)
    echo "Usage: cc-budget.sh {summary|sessions|projects|accuracy|daily} [args]"
    echo ""
    echo "Commands:"
    echo "  summary          Total sessions, tokens, tasks, avg tokens/session"
    echo "  sessions [N]     Last N sessions table (default: 10)"
    echo "  projects         Tokens + task count grouped by project/service"
    echo "  accuracy         Estimate vs actual comparison + calibration stats"
    echo "  daily [DATE]     Daily breakdown (default: today)"
    exit 1
    ;;
esac
