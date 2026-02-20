#!/bin/bash
# Claude Code Harness — Setup Script
# Installs hooks, skills, memory, and templates into your project.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/voxos-ai/harness/main/setup.sh | bash
#   — or —
#   git clone https://github.com/voxos-ai/harness.git && cd harness && bash setup.sh
#
# Prerequisites: jq, git, bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[harness]${NC} $1"; }
ok()    { echo -e "${GREEN}[harness]${NC} $1"; }
warn()  { echo -e "${YELLOW}[harness]${NC} $1"; }
fail()  { echo -e "${RED}[harness]${NC} $1"; exit 1; }

# --- Preflight checks ---

command -v jq >/dev/null 2>&1 || fail "jq is required. Install: https://jqlang.github.io/jq/download/"
command -v git >/dev/null 2>&1 || fail "git is required."

# Detect if we're inside a git repo
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$REPO_ROOT" ]; then
  fail "Not inside a git repository. Run this from your project root."
fi

# Determine source directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$SCRIPT_DIR/hooks" ]; then
  # Running via curl pipe — download to temp
  info "Downloading harness files..."
  TMPDIR=$(mktemp -d)
  git clone --depth 1 https://github.com/voxos-ai/harness.git "$TMPDIR/harness" 2>/dev/null
  SCRIPT_DIR="$TMPDIR/harness"
fi

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOKS_DEST="$REPO_ROOT/.claude/hooks"
SKILLS_DEST="$REPO_ROOT/.claude/skills"
MEMORY_DEST="$REPO_ROOT/.claude-memory"
SCRIPTS_DEST="$REPO_ROOT/scripts"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Claude Code Harness — Setup            ║${NC}"
echo -e "${CYAN}║   Session tracking, token budgeting,     ║${NC}"
echo -e "${CYAN}║   skills, maintenance cadence            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
info "Repo root: $REPO_ROOT"
echo ""

# --- Step 1: Install hooks ---

info "Step 1/5: Installing hooks..."
mkdir -p "$HOOKS_DEST"
for f in "$SCRIPT_DIR"/hooks/*.sh; do
  cp "$f" "$HOOKS_DEST/"
  chmod +x "$HOOKS_DEST/$(basename "$f")"
done
ok "  Hooks installed to $HOOKS_DEST"

# Create symlink/junction from ~/.claude/hooks → repo hooks
if [ ! -e "$CLAUDE_DIR/hooks" ] || [ "$(readlink -f "$CLAUDE_DIR/hooks" 2>/dev/null)" != "$(readlink -f "$HOOKS_DEST" 2>/dev/null)" ]; then
  # Backup existing hooks if any
  if [ -d "$CLAUDE_DIR/hooks" ] && [ ! -L "$CLAUDE_DIR/hooks" ]; then
    warn "  Backing up existing ~/.claude/hooks to ~/.claude/hooks.bak"
    mv "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/hooks.bak"
  elif [ -L "$CLAUDE_DIR/hooks" ]; then
    rm "$CLAUDE_DIR/hooks"
  fi

  # Platform-specific linking
  if command -v cygpath >/dev/null 2>&1; then
    # Windows/MSYS — use directory junction
    WIN_TARGET="$(cygpath -w "$HOOKS_DEST")"
    WIN_LINK="$(cygpath -w "$CLAUDE_DIR/hooks")"
    cmd //c "mklink /J \"$WIN_LINK\" \"$WIN_TARGET\"" >/dev/null 2>&1 || ln -s "$HOOKS_DEST" "$CLAUDE_DIR/hooks"
  else
    ln -s "$HOOKS_DEST" "$CLAUDE_DIR/hooks"
  fi
  ok "  Linked ~/.claude/hooks → $HOOKS_DEST"
else
  ok "  ~/.claude/hooks already linked"
fi

# --- Step 2: Install skills ---

info "Step 2/5: Installing skills..."
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  slug=$(basename "$skill_dir")
  dest="$SKILLS_DEST/$slug"
  if [ -d "$dest" ]; then
    warn "  Skipping $slug (already exists)"
  else
    mkdir -p "$dest"
    cp "$skill_dir"/* "$dest/"
    ok "  Installed /$slug"
  fi
done

# Link skills to ~/.claude/skills
if [ ! -e "$CLAUDE_DIR/skills" ] || [ "$(readlink -f "$CLAUDE_DIR/skills" 2>/dev/null)" != "$(readlink -f "$SKILLS_DEST" 2>/dev/null)" ]; then
  if [ -d "$CLAUDE_DIR/skills" ] && [ ! -L "$CLAUDE_DIR/skills" ]; then
    warn "  Backing up existing ~/.claude/skills to ~/.claude/skills.bak"
    mv "$CLAUDE_DIR/skills" "$CLAUDE_DIR/skills.bak"
  elif [ -L "$CLAUDE_DIR/skills" ]; then
    rm "$CLAUDE_DIR/skills"
  fi

  if command -v cygpath >/dev/null 2>&1; then
    WIN_TARGET="$(cygpath -w "$SKILLS_DEST")"
    WIN_LINK="$(cygpath -w "$CLAUDE_DIR/skills")"
    cmd //c "mklink /J \"$WIN_LINK\" \"$WIN_TARGET\"" >/dev/null 2>&1 || ln -s "$SKILLS_DEST" "$CLAUDE_DIR/skills"
  else
    ln -s "$SKILLS_DEST" "$CLAUDE_DIR/skills"
  fi
  ok "  Linked ~/.claude/skills → $SKILLS_DEST"
else
  ok "  ~/.claude/skills already linked"
fi

# --- Step 3: Configure global hooks in settings.json ---

info "Step 3/5: Configuring global hooks..."
mkdir -p "$CLAUDE_DIR"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Check if hooks are already configured
EXISTING_HOOKS=$(jq '.hooks // {}' "$SETTINGS_FILE" 2>/dev/null || echo '{}')

NEEDS_UPDATE=false
for event in SessionStart SessionEnd Stop; do
  case "$event" in
    SessionStart) HOOK_CMD="bash ~/.claude/hooks/session-register.sh" ;;
    SessionEnd)   HOOK_CMD="bash ~/.claude/hooks/session-end.sh" ;;
    Stop)         HOOK_CMD="bash ~/.claude/hooks/task-check.sh" ;;
  esac

  HAS_HOOK=$(echo "$EXISTING_HOOKS" | jq --arg e "$event" --arg cmd "$HOOK_CMD" '
    (.[$e] // []) | map(select(.command == $cmd)) | length > 0
  ')

  if [ "$HAS_HOOK" = "false" ]; then
    NEEDS_UPDATE=true
    break
  fi
done

if [ "$NEEDS_UPDATE" = "true" ]; then
  # Merge hooks into settings
  jq '
    .hooks = (.hooks // {}) |
    .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"type": "command", "command": "bash ~/.claude/hooks/session-register.sh"}] | unique_by(.command)) |
    .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"type": "command", "command": "bash ~/.claude/hooks/session-end.sh"}] | unique_by(.command)) |
    .hooks.Stop = ((.hooks.Stop // []) + [{"type": "command", "command": "bash ~/.claude/hooks/task-check.sh"}] | unique_by(.command))
  ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  ok "  Hooks registered in $SETTINGS_FILE"
else
  ok "  Hooks already registered"
fi

# --- Step 4: Install templates ---

info "Step 4/5: Installing templates..."
for tmpl in CLAUDE.md MAINTENANCE.md REMINDERS.md GOTCHAS.md MILESTONES.md; do
  dest="$REPO_ROOT/$tmpl"
  if [ -f "$dest" ]; then
    warn "  Skipping $tmpl (already exists)"
  else
    cp "$SCRIPT_DIR/templates/$tmpl" "$dest"
    ok "  Created $tmpl"
  fi
done

# AGENTS.md goes in .claude/
if [ ! -f "$REPO_ROOT/.claude/AGENTS.md" ]; then
  mkdir -p "$REPO_ROOT/.claude"
  cp "$SCRIPT_DIR/templates/AGENTS.md" "$REPO_ROOT/.claude/AGENTS.md"
  ok "  Created .claude/AGENTS.md"
else
  warn "  Skipping .claude/AGENTS.md (already exists)"
fi

# Memory directory
mkdir -p "$MEMORY_DEST"
if [ ! -f "$MEMORY_DEST/MEMORY.md" ]; then
  cp "$SCRIPT_DIR/templates/MEMORY.md" "$MEMORY_DEST/MEMORY.md"
  ok "  Created .claude-memory/MEMORY.md"
else
  warn "  Skipping .claude-memory/MEMORY.md (already exists)"
fi

# --- Step 5: Install analytics script ---

info "Step 5/5: Installing analytics..."
mkdir -p "$SCRIPTS_DEST"
if [ ! -f "$SCRIPTS_DEST/cc-budget.sh" ]; then
  cp "$SCRIPT_DIR/scripts/cc-budget.sh" "$SCRIPTS_DEST/cc-budget.sh"
  chmod +x "$SCRIPTS_DEST/cc-budget.sh"
  ok "  Installed scripts/cc-budget.sh"
else
  warn "  Skipping scripts/cc-budget.sh (already exists)"
fi

# --- Done ---

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Setup complete!                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Installed:"
echo "  .claude/hooks/          — Session tracking & task nudging"
echo "  .claude/skills/         — Slash commands (/commit, /done, /queue, /nu, /preview)"
echo "  .claude/AGENTS.md       — Skill registry"
echo "  .claude-memory/         — Persistent agent memory"
echo "  scripts/cc-budget.sh    — Token budget analytics"
echo "  CLAUDE.md               — Project instructions template"
echo "  MAINTENANCE.md          — Recurring task cadence"
echo "  REMINDERS.md            — Follow-up tracker"
echo "  GOTCHAS.md              — Operational workarounds log"
echo "  MILESTONES.md           — Progress tracker"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md — fill in your project details"
echo "  2. Start a Claude Code session — hooks will auto-register"
echo "  3. Run 'bash scripts/cc-budget.sh summary' after a few sessions"
echo "  4. Create custom skills with '/nu <slug> <description>'"
echo ""
