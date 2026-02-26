"""Statistical comparison of benchmark results.

Usage:
    python compare.py <label>                    # compare vanilla vs TAS within a run
    python compare.py <label_a> <label_b>        # compare two labeled runs
    python compare.py <label> --by-category      # breakdown by task category
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

from config import TAS, RESULTS_DIR, VANILLA


def load_results(label: str) -> list:
    """Load results from a labeled run."""
    results_file = RESULTS_DIR / label / "results.json"
    if not results_file.exists():
        print(f"Results not found: {results_file}")
        sys.exit(1)
    return json.loads(results_file.read_text())


def aggregate(results: list) -> dict:
    """Compute aggregate metrics from a list of trial results."""
    if not results:
        return {}

    n = len(results)
    successes = sum(1 for r in results if r["success"])

    times = sorted(r["wall_time_s"] for r in results)
    costs = [r["cost_usd"] for r in results]
    turns = [r["num_turns"] for r in results]
    files = [r["files_changed"] for r in results]

    return {
        "trials": n,
        "success_rate": successes / n,
        "successes": successes,
        "wall_time_median": _median(times),
        "wall_time_p25": _percentile(times, 25),
        "wall_time_p75": _percentile(times, 75),
        "cost_median": _median(costs),
        "cost_mean": sum(costs) / n,
        "turns_median": _median(turns),
        "files_changed_median": _median(files),
    }


def _median(values: list) -> float:
    s = sorted(values)
    n = len(s)
    if n == 0:
        return 0
    if n % 2 == 1:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2


def _percentile(values: list, p: int) -> float:
    s = sorted(values)
    n = len(s)
    if n == 0:
        return 0
    k = (n - 1) * (p / 100)
    f = int(k)
    c = min(f + 1, n - 1)
    return s[f] + (k - f) * (s[c] - s[f])


def wilcoxon_test(a_values: list, b_values: list) -> dict:
    """Run Wilcoxon signed-rank test on paired observations.

    Returns stat, p-value, and interpretation. Falls back to a simple
    sign test if scipy is not available.
    """
    if len(a_values) != len(b_values) or len(a_values) < 3:
        return {"stat": None, "p_value": None, "note": "insufficient paired data"}

    try:
        from scipy.stats import wilcoxon

        differences = [b - a for a, b in zip(a_values, b_values)]

        # Filter zero differences (ties)
        nonzero = [d for d in differences if d != 0]
        if len(nonzero) < 3:
            return {"stat": None, "p_value": None, "note": "too few non-tied pairs"}

        stat, p_value = wilcoxon(nonzero)
        return {
            "stat": round(stat, 4),
            "p_value": round(p_value, 6),
            "significant": p_value < 0.05,
        }
    except ImportError:
        # Fallback: simple sign test
        improvements = sum(1 for a, b in zip(a_values, b_values) if b < a)
        n = len(a_values)
        return {
            "stat": None,
            "p_value": None,
            "note": f"scipy not available; sign test: {improvements}/{n} improved",
        }


def delta_str(a: float, b: float) -> str:
    """Format a delta as absolute and percentage change."""
    if a == 0:
        return f"{b:+.2f}"
    pct = ((b - a) / abs(a)) * 100
    return f"{b - a:+.2f} ({pct:+.1f}%)"


def print_comparison(label_a: str, agg_a: dict, label_b: str, agg_b: dict, stats: dict = None):
    """Print a formatted comparison table."""
    col_w = 16
    header = f"{'Metric':<28} {label_a:>{col_w}} {label_b:>{col_w}} {'Delta':>{col_w}}"
    print(header)
    print("-" * len(header))

    rows = [
        ("Success rate", "success_rate", "{:.0%}"),
        ("Wall time (median, s)", "wall_time_median", "{:.1f}"),
        ("Wall time (IQR, s)", None, None),  # special handling
        ("Cost (median, $)", "cost_median", "${:.4f}"),
        ("Turns (median)", "turns_median", "{:.1f}"),
        ("Files changed (median)", "files_changed_median", "{:.1f}"),
    ]

    for label, key, fmt in rows:
        if key is None:
            # IQR row
            iqr_a = f"{agg_a.get('wall_time_p25', 0):.0f}-{agg_a.get('wall_time_p75', 0):.0f}"
            iqr_b = f"{agg_b.get('wall_time_p25', 0):.0f}-{agg_b.get('wall_time_p75', 0):.0f}"
            print(f"  {label:<26} {iqr_a:>{col_w}} {iqr_b:>{col_w}}")
            continue

        va = agg_a.get(key, 0)
        vb = agg_b.get(key, 0)

        if fmt.startswith("$"):
            sa = f"${va:.4f}"
            sb = f"${vb:.4f}"
        elif fmt.endswith("%}"):
            sa = f"{va:.0%}"
            sb = f"{vb:.0%}"
        else:
            sa = fmt.format(va)
            sb = fmt.format(vb)

        d = delta_str(va, vb)
        print(f"  {label:<26} {sa:>{col_w}} {sb:>{col_w}} {d:>{col_w}}")

    if stats:
        print()
        for metric, result in stats.items():
            if result.get("p_value") is not None:
                sig = "YES" if result["significant"] else "no"
                print(f"  Wilcoxon ({metric}): W={result['stat']}, p={result['p_value']:.4f} (sig: {sig})")
            elif result.get("note"):
                print(f"  Wilcoxon ({metric}): {result['note']}")


def cmd_compare_within(args):
    """Compare vanilla vs TAS within a single labeled run."""
    results = load_results(args.label)

    vanilla = [r for r in results if r["condition"] == VANILLA]
    tas_results = [r for r in results if r["condition"] == TAS]

    if not vanilla or not tas_results:
        print("Need both vanilla and TAS results for comparison.")
        sys.exit(1)

    agg_v = aggregate(vanilla)
    agg_h = aggregate(tas_results)

    # Paired statistics: match by task_id + trial
    pairs = _build_pairs(vanilla, tas_results)
    stats = {}
    if pairs:
        stats["wall_time"] = wilcoxon_test(
            [p[0]["wall_time_s"] for p in pairs],
            [p[1]["wall_time_s"] for p in pairs],
        )
        stats["cost"] = wilcoxon_test(
            [p[0]["cost_usd"] for p in pairs],
            [p[1]["cost_usd"] for p in pairs],
        )

    print(f"\n=== {args.label}: Vanilla vs TAS ===\n")
    print_comparison("vanilla", agg_v, "tas", agg_h, stats)

    if args.by_category:
        _print_category_breakdown(vanilla, tas_results)


def cmd_compare_across(args):
    """Compare two labeled runs."""
    results_a = load_results(args.label)
    results_b = load_results(args.label_b)

    agg_a = aggregate(results_a)
    agg_b = aggregate(results_b)

    print(f"\n=== {args.label} vs {args.label_b} ===\n")
    print_comparison(args.label, agg_a, args.label_b, agg_b)


def _build_pairs(vanilla: list, tas_results: list) -> list:
    """Match vanilla/TAS results by task_id + trial for paired tests."""
    v_index = {}
    for r in vanilla:
        key = (r["task_id"], r["trial"])
        v_index[key] = r

    pairs = []
    for r in tas_results:
        key = (r["task_id"], r["trial"])
        if key in v_index:
            pairs.append((v_index[key], r))

    return pairs


def _print_category_breakdown(vanilla: list, tas_results: list):
    """Print per-category comparison."""
    categories = sorted(set(r["category"] for r in vanilla + tas_results))

    for cat in categories:
        v_cat = [r for r in vanilla if r["category"] == cat]
        h_cat = [r for r in tas_results if r["category"] == cat]

        if not v_cat or not h_cat:
            continue

        agg_v = aggregate(v_cat)
        agg_h = aggregate(h_cat)

        print(f"\n--- {cat} ---\n")
        print_comparison("vanilla", agg_v, "tas", agg_h)


def main():
    parser = argparse.ArgumentParser(description="Compare benchmark results")
    parser.add_argument("label", help="Primary result label")
    parser.add_argument("label_b", nargs="?", help="Second label for cross-run comparison")
    parser.add_argument("--by-category", action="store_true", help="Show per-category breakdown")

    args = parser.parse_args()

    if args.label_b:
        cmd_compare_across(args)
    else:
        cmd_compare_within(args)


if __name__ == "__main__":
    main()
