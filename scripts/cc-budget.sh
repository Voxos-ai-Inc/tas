#!/bin/bash
# Analytics CLI for token budgeting system
# Usage: cc-budget.sh {summary|sessions|projects|accuracy|daily} [args]

# Source shared utils (try installed location, then repo layout)_HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.claude/hooks" 2>/dev/null && pwd)"   || _HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" 2>/dev/null && pwd)"if [ -f "$_HOOKS_DIR/utils.sh" ]; then  source "$_HOOKS_DIR/utils.sh"else  _path() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }fi
set -euo pipefail

TRACKING_DIR="$HOME/.claude/task-tracking"
TASKS_FILE="$TRACKING_DIR/tasks.jsonl"
SESSIONS_FILE="$TRACKING_DIR/sessions.jsonl"


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
        total_output_tokens: ([.[] | (.output_tokens // .estimated_output_tokens // 0)] | add // 0),
        total_input_tokens: ([.[] | (.input_tokens // .estimated_input_tokens // 0)] | add // 0),
        total_cache_creation: ([.[].cache_creation_tokens // 0] | add // 0),
        total_cache_read: ([.[].cache_read_tokens // 0] | add // 0),
        total_cost: ([.[].estimated_cost_usd // 0] | add // 0),
        avg_output_tokens_per_session: (([.[] | (.output_tokens // .estimated_output_tokens // 0)] | add // 0) / (length | if . == 0 then 1 else . end) | round),
        avg_turns_per_session: (([.[].turn_count] | add // 0) / (length | if . == 0 then 1 else . end) | . * 10 | round / 10),
        total_compacts: ([.[].compact_count] | add // 0)
      }
    ' "$WIN_SF" | jq --argjson tasks "$TOTAL_TASKS" '. + {total_tasks: $tasks}' | jq -r '
      "=== Token Budget Summary ===",
      "Sessions:        \(.total_sessions)",
      "Total duration:  \(.total_duration_hours)h",
      "Output tokens:   \(.total_output_tokens | . / 1000 | . * 10 | round / 10)k",
      "Input tokens:    \(.total_input_tokens | . / 1000 | . * 10 | round / 10)k",
      "Cache create:    \(.total_cache_creation | . / 1000 | . * 10 | round / 10)k",
      "Cache read:      \(.total_cache_read | . / 1000 | . * 10 | round / 10)k",
      "Total cost:      $\(.total_cost | . * 100 | round / 100)",
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
    printf "%-12s  %5s  %8s  %7s  %-16s  %5s  %s\n" "DATE" "MIN" "OUT_TOK" "COST" "MODEL" "TASKS" "PROJECTS"
    printf "%-12s  %5s  %8s  %7s  %-16s  %5s  %s\n" "------------" "-----" "--------" "-------" "----------------" "-----" "--------"

    jq -s "sort_by(.started_at) | reverse | .[:$LIMIT] | reverse | .[]" "$WIN_SF" | jq -r '
      [
        (.started_at[:10] // "?"),
        (.duration_minutes | tostring),
        (((.output_tokens // .estimated_output_tokens // 0) / 1000 | . * 10 | round / 10 | tostring) + "k"),
        (if .estimated_cost_usd then ("$" + (.estimated_cost_usd | . * 100 | round / 100 | tostring)) else "-" end),
        (.model // "unknown"),
        (.task_count | tostring),
        ((.projects_touched // []) | join(",") | if . == "" then "-" else . end)
      ] | @tsv
    ' | while IFS=$'\t' read -r date dur tok cost model tasks projs; do
      printf "%-12s  %5s  %8s  %7s  %-16s  %5s  %s\n" "$date" "$dur" "$tok" "$cost" "$model" "$tasks" "$projs"
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

    # Join estimates with completions by task_id
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
          actual: $c.reported_tokens,
          ratio: (($c.reported_tokens / .estimated) * 100 | round / 100)
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

    # Calibration stats
    echo ""
    echo "--- Calibration ---"
    jq -s '
      (
        [.[] | select(.event == "estimate")] | map({(.task_id): .estimated_tokens}) | add // {}
      ) as $est |
      [.[] | select(.event == "complete")] |
      map(($est[.task_id] // null) as $e | if $e then {est: $e, act: .reported_tokens} else empty end) |
      if length == 0 then {count: 0, avg_ratio: 0, overestimates: 0, underestimates: 0}
      else {
        count: length,
        avg_ratio: ([.[] | .act / .est] | add / length | . * 100 | round / 100),
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
        output_tokens: ([.[] | (.output_tokens // .estimated_output_tokens // 0)] | add),
        input_tokens: ([.[] | (.input_tokens // .estimated_input_tokens // 0)] | add),
        cache_creation: ([.[].cache_creation_tokens // 0] | add),
        cache_read: ([.[].cache_read_tokens // 0] | add),
        total_cost: ([.[].estimated_cost_usd // 0] | add),
        turns: ([.[].turn_count] | add),
        tasks: ([.[].task_count] | add),
        compacts: ([.[].compact_count] | add),
        projects: ([.[].projects_touched | .[]?] | unique),
        top_tools: ([.[].tool_counts // {} | to_entries[]] | group_by(.key) | map({key: .[0].key, count: ([.[].value] | add)}) | sort_by(-.count) | .[:5])
      } end
    ' "$WIN_SF" | jq -r '
      if .sessions == 0 then "No sessions found for this date."
      else
        "Sessions:       \(.sessions)",
        "Duration:       \(.duration_minutes)min",
        "Output tokens:  \(.output_tokens / 1000 | . * 10 | round / 10)k",
        "Input tokens:   \(.input_tokens / 1000 | . * 10 | round / 10)k",
        "Cache create:   \(.cache_creation / 1000 | . * 10 | round / 10)k",
        "Cache read:     \(.cache_read / 1000 | . * 10 | round / 10)k",
        "Total cost:     $\(.total_cost | . * 100 | round / 100)",
        "Turns:          \(.turns)",
        "Tasks:          \(.tasks)",
        "Compacts:       \(.compacts)",
        "Projects:       \(.projects | join(", "))",
        "Top tools:      \(.top_tools | map("\(.key):\(.count)") | join(", "))"
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
