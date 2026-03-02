#!/bin/bash
# build-brand.sh — Generate a standalone branded repo from the TAS source.
#
# Usage: bash build-brand.sh <brand>
#   e.g. bash build-brand.sh goblin
#
# Output: dist/<brand>/ — a complete, publishable repo with all brand
#         references rewritten. Ready for git init + push.

set -euo pipefail

BRAND="${1:?Usage: build-brand.sh <brand>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAND_DIR="$SCRIPT_DIR/brands/$BRAND"
DIST="$SCRIPT_DIR/dist/$BRAND"

# --- Load brand config ---
if [ ! -f "$BRAND_DIR/brand.conf" ]; then
  echo "ERROR: brands/$BRAND/brand.conf not found." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$BRAND_DIR/brand.conf"

echo "Building brand: $BRAND_NAME ($BRAND_GH_URL)"

# --- Copy repo into dist ---
rm -rf "$DIST"
mkdir -p "$DIST"

# Use tar pipe (rsync not available on Windows Git Bash)
(cd "$SCRIPT_DIR" && tar cf - \
  --exclude='./brands' \
  --exclude='./dist' \
  --exclude='./.git' \
  --exclude='./build-brand.sh' \
  --exclude='./publish-brand.sh' \
  .) | (cd "$DIST" && tar xf -)

echo "  Copied source to dist/$BRAND/"

# --- Place logo + favicons ---
mkdir -p "$DIST/.github"
if [ -f "$BRAND_DIR/logo.png" ]; then
  cp "$BRAND_DIR/logo.png" "$DIST/.github/$BRAND_LOGO_FILE"
  echo "  Logo: .github/$BRAND_LOGO_FILE"
fi
for f in favicon.svg favicon.ico; do
  if [ -f "$BRAND_DIR/$f" ]; then
    cp "$BRAND_DIR/$f" "$DIST/.github/$f"
    echo "  Favicon: .github/$f"
  fi
done

# Remove source logo if brand uses a different filename
# shellcheck source=/dev/null
source "$SCRIPT_DIR/brands/tas/brand.conf"
SRC_LOGO_FILE="$BRAND_LOGO_FILE"
# shellcheck source=/dev/null
source "$BRAND_DIR/brand.conf"
if [ "$BRAND_LOGO_FILE" != "$SRC_LOGO_FILE" ] && [ -f "$DIST/.github/$SRC_LOGO_FILE" ]; then
  rm -f "$DIST/.github/$SRC_LOGO_FILE"
fi

# --- Rewrite branded files using Python (reliable multiline + regex) ---
# Find a working python (python3 may be a Windows Store stub)
PYTHON=""
for candidate in python3 python; do
  if "$candidate" -c "import sys" 2>/dev/null; then
    PYTHON="$candidate"
    break
  fi
done
[ -z "$PYTHON" ] && { echo "ERROR: python not found" >&2; exit 1; }

# Convert paths for Python (handles MSYS /c/... → C:\...)
_pypath() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    echo "$1"
  fi
}
"$PYTHON" - "$(_pypath "$SCRIPT_DIR")" "$(_pypath "$BRAND_DIR")" "$(_pypath "$DIST")" <<'PYEOF'
import sys, os, re

script_dir, brand_dir, dist = sys.argv[1], sys.argv[2], sys.argv[3]

def load_conf(path):
    """Parse a shell brand.conf into a dict."""
    conf = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, val = line.split("=", 1)
            # Strip quotes
            val = val.strip()
            if val.startswith('"') and val.endswith('"'):
                val = val[1:-1]
            conf[key] = val
    return conf

# Load multiline values from brand.conf (re-parse to get BRAND_NARRATIVE etc.)
def load_conf_multiline(path):
    """Parse brand.conf handling multiline quoted values."""
    conf = {}
    with open(path, encoding="utf-8") as f:
        content = f.read()
    # Match KEY="value" where value can span multiple lines
    for m in re.finditer(r'^(\w+)="((?:[^"\\]|\\.)*)"\s*$', content, re.MULTILINE | re.DOTALL):
        conf[m.group(1)] = m.group(2).replace('\\"', '"')
    return conf

src = load_conf_multiline(os.path.join(script_dir, "brands", "tas", "brand.conf"))
tgt = load_conf_multiline(os.path.join(brand_dir, "brand.conf"))

def rw(relpath):
    """Read a file from dist."""
    p = os.path.join(dist, relpath)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        return f.read()

def ww(relpath, content):
    """Write a file to dist."""
    p = os.path.join(dist, relpath)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"  Rewrote {relpath}")

# Helper: replace all occurrences
def rep(text, old, new):
    return text.replace(old, new)

# ---- README.md ----
txt = rw("README.md")
if txt:
    # Title
    txt = rep(txt, f"# {src['BRAND_FULL_NAME']}", f"# {tgt['BRAND_FULL_NAME']}")
    # Logo
    txt = rep(txt, src["BRAND_LOGO_FILE"], tgt["BRAND_LOGO_FILE"])
    # Tagline
    txt = rep(txt, src["BRAND_TAGLINE"], tgt["BRAND_TAGLINE"])
    # Narrative (replace the 3 TAS paragraphs with new brand paragraphs)
    # The narrative sits between the tagline closing tag and "## What You Get"
    old_narrative = src["BRAND_NARRATIVE"]
    new_narrative = tgt["BRAND_NARRATIVE"]
    txt = rep(txt, old_narrative, new_narrative)
    # GitHub URLs
    txt = rep(txt, src["BRAND_GH_URL"], tgt["BRAND_GH_URL"])
    txt = rep(txt, f"{src['BRAND_GH_ORG']}/{src['BRAND_GH_REPO']}", f"{tgt['BRAND_GH_ORG']}/{tgt['BRAND_GH_REPO']}")
    # FAQ
    txt = rep(txt, src["BRAND_FAQ_Q"], tgt["BRAND_FAQ_Q"])
    txt = rep(txt, src["BRAND_FAQ_A"], tgt["BRAND_FAQ_A"])
    # Standalone name references (word boundary via regex)
    # Replace "TAS" as a standalone word but not inside URLs or other words
    txt = re.sub(r'\bTAS\b', tgt["BRAND_NAME"], txt)
    ww("README.md", txt)

# ---- setup.sh ----
txt = rw("setup.sh")
if txt:
    txt = rep(txt, "# TAS Setup Script", f"# {tgt['BRAND_NAME']} Setup Script")
    txt = rep(txt, "[tas]", f"[{tgt['BRAND_LOG_PREFIX']}]")
    txt = rep(txt, "TAS_TMPDIR", tgt["BRAND_TMPDIR_VAR"])
    txt = rep(txt, src["BRAND_GH_URL"], tgt["BRAND_GH_URL"])
    txt = rep(txt, f"{src['BRAND_GH_ORG']}/{src['BRAND_GH_REPO']}", f"{tgt['BRAND_GH_ORG']}/{tgt['BRAND_GH_REPO']}")
    txt = rep(txt, "TAS Setup", tgt["BRAND_BANNER_TITLE"])
    txt = rep(txt, "TAS files", f"{tgt['BRAND_NAME']} files")
    txt = rep(txt, "Remove TAS from", f"Remove {tgt['BRAND_NAME']} from")
    txt = rep(txt, "Uninstalling TAS from", f"Uninstalling {tgt['BRAND_NAME']} from")
    ww("setup.sh", txt)

# ---- docs/index.html ----
txt = rw("docs/index.html")
if txt:
    txt = rep(txt, "<title>TAS", f"<title>{tgt['BRAND_NAME']}")
    txt = rep(txt, f"<span>{src['BRAND_NAME']}</span>", f"<span>{tgt['BRAND_NAME']}</span>")
    txt = rep(txt, f"--accent: {src['BRAND_ACCENT']}", f"--accent: {tgt['BRAND_ACCENT']}")
    txt = rep(txt, f"--accent-dim: {src['BRAND_ACCENT_DIM']}", f"--accent-dim: {tgt['BRAND_ACCENT_DIM']}")
    txt = rep(txt, f"--code-bg: {src['BRAND_CODE_BG']}", f"--code-bg: {tgt['BRAND_CODE_BG']}")
    txt = rep(txt, src["BRAND_GH_URL"], tgt["BRAND_GH_URL"])
    txt = rep(txt, f"{src['BRAND_GH_ORG']}/{src['BRAND_GH_REPO']}", f"{tgt['BRAND_GH_ORG']}/{tgt['BRAND_GH_REPO']}")
    ww("docs/index.html", txt)

# ---- CONTRIBUTING.md ----
txt = rw("CONTRIBUTING.md")
if txt:
    txt = rep(txt, f"Contributing to {src['BRAND_NAME']}", f"Contributing to {tgt['BRAND_NAME']}")
    txt = rep(txt, "with TAS installed", f"with {tgt['BRAND_NAME']} installed")
    ww("CONTRIBUTING.md", txt)

# ---- SETUP.md ----
txt = rw("SETUP.md")
if txt:
    txt = rep(txt, "install or set up TAS", f"install or set up {tgt['BRAND_NAME']}")
    txt = rep(txt, "<path-to-tas>", f"<path-to-{tgt['BRAND_NAME_LOWER']}>")
    ww("SETUP.md", txt)

# ---- bench/config.py ----
txt = rw("bench/config.py")
if txt:
    txt = rep(txt, "TAS_ROOT", tgt["BRAND_BENCH_ROOT"])
    txt = rep(txt, 'TAS_CLAUDE_MD', tgt["BRAND_BENCH_CLAUDE_MD"])
    # TAS = "tas" constant (careful: only the standalone assignment)
    txt = re.sub(r'^TAS = ', f'{tgt["BRAND_BENCH_CONST"]} = ', txt, flags=re.MULTILINE)
    txt = rep(txt, '"tas"', f'"{tgt["BRAND_NAME_LOWER"]}"')
    # String references
    txt = rep(txt, "# TAS CLAUDE.md", f"# {tgt['BRAND_NAME']} CLAUDE.md")
    txt = rep(txt, "TAS-condition", f"{tgt['BRAND_NAME']}-condition")
    # CONDITIONS list references
    txt = rep(txt, "[VANILLA, TAS]", f"[VANILLA, {tgt['BRAND_BENCH_CONST']}]")
    ww("bench/config.py", txt)

# ---- bench/runner.py ----
txt = rw("bench/runner.py")
if txt:
    # Imports
    txt = rep(txt, "    TAS,\n", f"    {tgt['BRAND_BENCH_CONST']},\n")
    txt = rep(txt, "    TAS_CLAUDE_MD,\n", f"    {tgt['BRAND_BENCH_CLAUDE_MD']},\n")
    # Usage in code
    txt = rep(txt, "condition == TAS", f"condition == {tgt['BRAND_BENCH_CONST']}")
    txt = rep(txt, "TAS_CLAUDE_MD.format", f"{tgt['BRAND_BENCH_CLAUDE_MD']}.format")
    # Strings
    txt = rep(txt, "TAS benchmark runner", f"{tgt['BRAND_NAME']} benchmark runner")
    txt = rep(txt, "Install TAS scaffolding", f"Install {tgt['BRAND_NAME']} scaffolding")
    txt = rep(txt, "TAS files", f"{tgt['BRAND_NAME']} files")
    txt = rep(txt, "for the TAS condition", f"for the {tgt['BRAND_NAME']} condition")
    # Inject comment at top noting the TAS variable still means "with-harness" condition
    ww("bench/runner.py", txt)

# ---- bench/compare.py ----
txt = rw("bench/compare.py")
if txt:
    txt = rep(txt, "from config import TAS,", f"from config import {tgt['BRAND_BENCH_CONST']},")
    txt = rep(txt, "== TAS]", f"== {tgt['BRAND_BENCH_CONST']}]")
    txt = rep(txt, "== TAS:", f"== {tgt['BRAND_BENCH_CONST']}:")
    txt = rep(txt, "vanilla vs TAS", f"vanilla vs {tgt['BRAND_NAME']}")
    txt = rep(txt, "vanilla vs. TAS", f"vanilla vs. {tgt['BRAND_NAME']}")
    txt = rep(txt, "Vanilla vs TAS", f"Vanilla vs {tgt['BRAND_NAME']}")
    # Variable names and comments
    bname_lower = tgt["BRAND_NAME_LOWER"]
    txt = rep(txt, "tas_results", f"{bname_lower}_results")
    txt = rep(txt, "vanilla and TAS results", f"vanilla and {tgt['BRAND_NAME']} results")
    txt = rep(txt, "vanilla/TAS results", f"vanilla/{tgt['BRAND_NAME']} results")
    ww("bench/compare.py", txt)

# ---- bench/README.md ----
txt = rw("bench/README.md")
if txt:
    txt = re.sub(r'\bTAS\b', tgt["BRAND_NAME"], txt)
    ww("bench/README.md", txt)

# ---- hooks/utils.sh ----
txt = rw("hooks/utils.sh")
if txt:
    txt = rep(txt, "Shared utilities for TAS", f"Shared utilities for {tgt['BRAND_NAME']}")
    ww("hooks/utils.sh", txt)

PYEOF

# --- Validation ---
echo ""
echo "Validating..."
ERRORS=0

# Load source values for validation
# shellcheck source=/dev/null
source "$SCRIPT_DIR/brands/tas/brand.conf"
SRC_GH_REPO_CHECK="$BRAND_GH_REPO"
# shellcheck source=/dev/null
source "$BRAND_DIR/brand.conf"

# Check for leftover source GitHub repo references
if [ "$BRAND_GH_REPO" != "$SRC_GH_REPO_CHECK" ]; then
  LEAKS=$(grep -rn "Voxos-ai-Inc/${SRC_GH_REPO_CHECK}" \
    "$DIST/README.md" "$DIST/setup.sh" "$DIST/CONTRIBUTING.md" "$DIST/SETUP.md" \
    "$DIST/docs/index.html" "$DIST/bench/config.py" "$DIST/bench/runner.py" "$DIST/bench/compare.py" \
    2>/dev/null || true)
  if [ -n "$LEAKS" ]; then
    echo "  WARN: Found leftover Voxos-ai-Inc/${SRC_GH_REPO_CHECK} references:"
    echo "$LEAKS" | head -10
    ERRORS=$((ERRORS + 1))
  fi
fi

# For non-TAS brands, check for leftover "TAS" as a standalone word in branded files
if [ "$BRAND_NAME" != "TAS" ]; then
  # Exclude: CONDITIONS list (contains "vanilla", "tas" lowercase), bench template comments
  LEAKS=$(grep -Pn '\bTAS\b' \
    "$DIST/README.md" "$DIST/setup.sh" "$DIST/CONTRIBUTING.md" "$DIST/SETUP.md" \
    "$DIST/docs/index.html" "$DIST/bench/config.py" "$DIST/bench/runner.py" "$DIST/bench/compare.py" \
    "$DIST/bench/README.md" "$DIST/hooks/utils.sh" \
    2>/dev/null || true)
  if [ -n "$LEAKS" ]; then
    echo "  WARN: Found leftover TAS references in branded files:"
    echo "$LEAKS" | head -10
    ERRORS=$((ERRORS + 1))
  fi
fi

if [ "$ERRORS" -eq 0 ]; then
  echo "  All clean."
else
  echo "  $ERRORS validation warning(s). Review above."
fi

echo ""
echo "Done. Output: dist/$BRAND/"
echo "  Files: $(find "$DIST" -type f | wc -l | tr -d ' ')"
echo "  Size:  $(du -sh "$DIST" | cut -f1)"
