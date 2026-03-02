#!/bin/bash
# publish-brand.sh — Build a brand and push it to its GitHub repo.
#
# Usage: bash publish-brand.sh <brand>
#   e.g. bash publish-brand.sh goblin
#
# Prerequisites: gh CLI authenticated, target repo must exist on GitHub.

set -euo pipefail

BRAND="${1:?Usage: publish-brand.sh <brand>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAND_DIR="$SCRIPT_DIR/brands/$BRAND"
DIST="$SCRIPT_DIR/dist/$BRAND"
PUBLISH_DIR="$SCRIPT_DIR/dist/.publish-${BRAND}"

# Load brand config
if [ ! -f "$BRAND_DIR/brand.conf" ]; then
  echo "ERROR: brands/$BRAND/brand.conf not found." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$BRAND_DIR/brand.conf"

# Step 1: Build
echo "=== Building $BRAND_NAME ==="
bash "$SCRIPT_DIR/build-brand.sh" "$BRAND"
echo ""

# Step 2: Clone or update the target repo
echo "=== Publishing to $BRAND_GH_URL ==="
if [ -d "$PUBLISH_DIR/.git" ]; then
  echo "  Updating existing clone..."
  cd "$PUBLISH_DIR"
  git fetch origin 2>/dev/null || true
  git reset --hard origin/main 2>/dev/null || git reset --hard HEAD
  cd "$SCRIPT_DIR"
else
  rm -rf "$PUBLISH_DIR"
  if ! gh repo view "$BRAND_GH_ORG/$BRAND_GH_REPO" >/dev/null 2>&1; then
    echo "  Repo not found. Creating $BRAND_GH_ORG/$BRAND_GH_REPO..."
    gh repo create "$BRAND_GH_ORG/$BRAND_GH_REPO" --public --description "$BRAND_TAGLINE"
  fi
  # Clone; if repo is empty, init locally instead
  if ! git clone "$BRAND_GH_URL.git" "$PUBLISH_DIR" 2>/dev/null; then
    echo "  Empty repo, initializing locally..."
    mkdir -p "$PUBLISH_DIR"
    cd "$PUBLISH_DIR"
    git init -b main
    git remote add origin "$BRAND_GH_URL.git"
    cd "$SCRIPT_DIR"
  fi
fi

# Step 3: Sync dist into the publish directory (preserve .git)
# Remove everything except .git, then copy fresh from dist
find "$PUBLISH_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -r "$DIST"/. "$PUBLISH_DIR/"

# Step 4: Commit and push
cd "$PUBLISH_DIR"
TAS_HASH=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

git add -A
if git diff --cached --quiet 2>/dev/null; then
  echo "  No changes to publish."
else
  git commit -m "sync: upstream $TAS_HASH"
  git push -u origin HEAD 2>/dev/null || git push --set-upstream origin main
  echo ""
  echo "  Published to $BRAND_GH_URL"
fi

cd "$SCRIPT_DIR"
echo "Done."
