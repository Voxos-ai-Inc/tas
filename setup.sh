#!/bin/bash
# TAS Setup Script
# Installs hooks, skills, memory, and templates into your project.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Voxos-ai-Inc/tas/main/setup.sh | bash
#   git clone https://github.com/Voxos-ai-Inc/tas.git && cd tas && bash setup.sh
#
# Flags:
#   --dry-run     Print what would be done without making changes
#   --uninstall   Remove TAS from the current project
#
# Prerequisites: jq, git, bash

set -euo pipefail

# Cross-platform readlink -f
_readlink_f() { readlink -f "$1" 2>/dev/null || realpath "$1" 2>/dev/null || echo "$1"; }

# --- Argument parsing ---
DRY_RUN=false
UNINSTALL=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=true ;;
    --uninstall) UNINSTALL=true ;;
    *) echo "Unknown flag: $arg"; echo "Usage: setup.sh [--dry-run] [--uninstall]"; exit 1 ;;
  esac
done

# run() wrapper: prints instead of executing in dry-run mode
run() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[tas]${NC} $1"; }
ok()    { echo -e "${GREEN}[tas]${NC} $1"; }
warn()  { echo -e "${YELLOW}[tas]${NC} $1"; }
fail()  { echo -e "${RED}[tas]${NC} $1"; exit 1; }

# --- Preflight checks ---

command -v jq >/dev/null 2>&1 || fail "jq is required. Install: https://jqlang.github.io/jq/download/"
command -v git >/dev/null 2>&1 || fail "git is required."

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$REPO_ROOT" ]; then
  fail "Not inside a git repository. Run this from your project root."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$SCRIPT_DIR/hooks" ]; then
  info "Downloading TAS files..."
  TAS_TMPDIR=$(mktemp -d)
  git clone --depth 1 https://github.com/Voxos-ai-Inc/tas.git "$TAS_TMPDIR/tas" 2>/dev/null
  SCRIPT_DIR="$TAS_TMPDIR/tas"
fi

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOKS_DEST="$REPO_ROOT/.claude/hooks"
SKILLS_DEST="$REPO_ROOT/.claude/skills"
MEMORY_DEST="$REPO_ROOT/.claude-memory"
SCRIPTS_DEST="$REPO_ROOT/scripts"

# --- Uninstall mode ---
if [ "$UNINSTALL" = true ]; then
  echo ""
  info "Uninstalling TAS from $REPO_ROOT"
  echo ""

  for link in "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills"; do
    if [ -L "$link" ]; then
      run rm "$link"
      ok "  Removed symlink $link"
    fi
  done

  if [ -f "$SETTINGS_FILE" ]; then
    for hook in session-register.sh session-end.sh task-check.sh input-capture.sh; do
      if jq -e ".hooks | to_entries[] | .value[] | select(.command | contains(\"$hook\"))" "$SETTINGS_FILE" >/dev/null 2>&1; then
        if [ "$DRY_RUN" = true ]; then
          echo "  [dry-run] Remove $hook from settings.json"
        else
          jq "(.hooks // {}) |= with_entries(.value |= map(select(.command | contains(\"$hook\") | not)))" \
            "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
          ok "  Removed $hook from settings.json"
        fi
      fi
    done
  fi

  echo ""
  info "Repo files remain in place (remove manually if desired):"
  for f in .claude/hooks .claude/skills .claude/AGENTS.md .claude-memory scripts/cc-budget.sh \
           CLAUDE.md MAINTENANCE.md REMINDERS.md GOTCHAS.md MILESTONES.md; do
    [ -e "$REPO_ROOT/$f" ] && echo "  $REPO_ROOT/$f"
  done
  echo ""
  ok "Uninstall complete. Data in ~/.claude/ (sessions, tasks, telemetry) is preserved."
  exit 0
fi

# --- Install mode ---

echo ""
echo -e "${CYAN}+==========================================+${NC}"
echo -e "${CYAN}|   TAS Setup                              |${NC}"
echo -e "${CYAN}|   Session tracking, token budgeting,     |${NC}"
echo -e "${CYAN}|   input telemetry, skills, maintenance   |${NC}"
echo -e "${CYAN}+==========================================+${NC}"
echo ""
info "Repo root: $REPO_ROOT"
[ "$DRY_RUN" = true ] && info "Mode: DRY RUN (no changes will be made)"
echo ""

# --- Step 1: Install hooks ---

info "Step 1/6: Installing hooks..."
run mkdir -p "$HOOKS_DEST"
for f in "$SCRIPT_DIR"/hooks/*.sh; do
  run cp "$f" "$HOOKS_DEST/"
  run chmod +x "$HOOKS_DEST/$(basename "$f")"
done
ok "  Hooks installed to $HOOKS_DEST"

if [ ! -e "$CLAUDE_DIR/hooks" ] || [ "$(_readlink_f "$CLAUDE_DIR/hooks" 2>/dev/null)" != "$(_readlink_f "$HOOKS_DEST" 2>/dev/null)" ]; then
  if [ -d "$CLAUDE_DIR/hooks" ] && [ ! -L "$CLAUDE_DIR/hooks" ]; then
    warn "  Backing up existing ~/.claude/hooks to ~/.claude/hooks.bak"
    run mv "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/hooks.bak"
  elif [ -L "$CLAUDE_DIR/hooks" ]; then
    run rm "$CLAUDE_DIR/hooks"
  fi

  if command -v cygpath >/dev/null 2>&1; then
    WIN_TARGET="$(cygpath -w "$HOOKS_DEST")"
    WIN_LINK="$(cygpath -w "$CLAUDE_DIR/hooks")"
    run cmd //c "mklink /J \"$WIN_LINK\" \"$WIN_TARGET\"" >/dev/null 2>&1 || run ln -s "$HOOKS_DEST" "$CLAUDE_DIR/hooks"
  else
    run ln -s "$HOOKS_DEST" "$CLAUDE_DIR/hooks"
  fi
  ok "  Linked ~/.claude/hooks to $HOOKS_DEST"
else
  ok "  ~/.claude/hooks already linked"
fi

# --- Step 2: Install skills ---

info "Step 2/6: Installing skills..."
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  slug=$(basename "$skill_dir")
  dest="$SKILLS_DEST/$slug"
  if [ -d "$dest" ]; then
    warn "  Skipping $slug (already exists)"
  else
    run mkdir -p "$dest"
    run cp "$skill_dir"/* "$dest/"
    ok "  Installed /$slug"
  fi
done

if [ ! -e "$CLAUDE_DIR/skills" ] || [ "$(_readlink_f "$CLAUDE_DIR/skills" 2>/dev/null)" != "$(_readlink_f "$SKILLS_DEST" 2>/dev/null)" ]; then
  if [ -d "$CLAUDE_DIR/skills" ] && [ ! -L "$CLAUDE_DIR/skills" ]; then
    warn "  Backing up existing ~/.claude/skills to ~/.claude/skills.bak"
    run mv "$CLAUDE_DIR/skills" "$CLAUDE_DIR/skills.bak"
  elif [ -L "$CLAUDE_DIR/skills" ]; then
    run rm "$CLAUDE_DIR/skills"
  fi

  if command -v cygpath >/dev/null 2>&1; then
    WIN_TARGET="$(cygpath -w "$SKILLS_DEST")"
    WIN_LINK="$(cygpath -w "$CLAUDE_DIR/skills")"
    run cmd //c "mklink /J \"$WIN_LINK\" \"$WIN_TARGET\"" >/dev/null 2>&1 || run ln -s "$SKILLS_DEST" "$CLAUDE_DIR/skills"
  else
    run ln -s "$SKILLS_DEST" "$CLAUDE_DIR/skills"
  fi
  ok "  Linked ~/.claude/skills to $SKILLS_DEST"
else
  ok "  ~/.claude/skills already linked"
fi

# --- Step 3: Configure global hooks in settings.json ---

info "Step 3/6: Configuring global hooks..."
run mkdir -p "$CLAUDE_DIR"

if [ ! -f "$SETTINGS_FILE" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Create $SETTINGS_FILE"
  else
    echo '{}' > "$SETTINGS_FILE"
  fi
fi

if [ "$DRY_RUN" = false ]; then
  EXISTING_HOOKS=$(jq '.hooks // {}' "$SETTINGS_FILE" 2>/dev/null || echo '{}')
  NEEDS_UPDATE=false
  for event in SessionStart SessionEnd Stop UserPromptSubmit; do
    case "$event" in
      SessionStart)      HOOK_CMD="bash ~/.claude/hooks/session-register.sh" ;;
      SessionEnd)        HOOK_CMD="bash ~/.claude/hooks/session-end.sh" ;;
      Stop)              HOOK_CMD="bash ~/.claude/hooks/task-check.sh" ;;
      UserPromptSubmit)  HOOK_CMD="bash ~/.claude/hooks/input-capture.sh" ;;
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
    jq '
      .hooks = (.hooks // {}) |
      .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"type": "command", "command": "bash ~/.claude/hooks/session-register.sh"}] | unique_by(.command)) |
      .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"type": "command", "command": "bash ~/.claude/hooks/session-end.sh"}] | unique_by(.command)) |
      .hooks.Stop = ((.hooks.Stop // []) + [{"type": "command", "command": "bash ~/.claude/hooks/task-check.sh"}] | unique_by(.command)) |
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"type": "command", "command": "bash ~/.claude/hooks/input-capture.sh"}] | unique_by(.command))
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    ok "  Hooks registered in $SETTINGS_FILE"
  else
    ok "  Hooks already registered"
  fi
else
  echo "  [dry-run] Would register hooks in $SETTINGS_FILE"
fi

# --- Step 4: Install templates ---

info "Step 4/6: Installing templates..."
for tmpl in CLAUDE.md MAINTENANCE.md REMINDERS.md GOTCHAS.md MILESTONES.md; do
  dest="$REPO_ROOT/$tmpl"
  if [ -f "$dest" ]; then
    warn "  Skipping $tmpl (already exists)"
  else
    run cp "$SCRIPT_DIR/templates/$tmpl" "$dest"
    ok "  Created $tmpl"
  fi
done

if [ ! -f "$REPO_ROOT/.claude/AGENTS.md" ]; then
  run mkdir -p "$REPO_ROOT/.claude"
  run cp "$SCRIPT_DIR/templates/AGENTS.md" "$REPO_ROOT/.claude/AGENTS.md"
  ok "  Created .claude/AGENTS.md"
else
  warn "  Skipping .claude/AGENTS.md (already exists)"
fi

run mkdir -p "$MEMORY_DEST"
if [ ! -f "$MEMORY_DEST/MEMORY.md" ]; then
  run cp "$SCRIPT_DIR/templates/MEMORY.md" "$MEMORY_DEST/MEMORY.md"
  ok "  Created .claude-memory/MEMORY.md"
else
  warn "  Skipping .claude-memory/MEMORY.md (already exists)"
fi

# --- Step 5: Install analytics scripts ---

info "Step 5/6: Installing analytics..."
run mkdir -p "$SCRIPTS_DEST"
if [ ! -f "$SCRIPTS_DEST/cc-budget.sh" ]; then
  run cp "$SCRIPT_DIR/scripts/cc-budget.sh" "$SCRIPTS_DEST/cc-budget.sh"
  run chmod +x "$SCRIPTS_DEST/cc-budget.sh"
  ok "  Installed scripts/cc-budget.sh"
else
  warn "  Skipping scripts/cc-budget.sh (already exists)"
fi

# --- Step 6: Create data directories ---

info "Step 6/6: Creating data directories..."
run mkdir -p "$HOME/.claude/session-tracking"
run mkdir -p "$HOME/.claude/task-tracking"
run mkdir -p "$HOME/.claude/input-telemetry"
ok "  Data directories ready"

# --- Done ---

echo ""
echo -e "${GREEN}+==========================================+${NC}"
echo -e "${GREEN}|   Setup complete!                        |${NC}"
echo -e "${GREEN}+==========================================+${NC}"
echo ""
echo "Installed:"
echo "  .claude/hooks/        Session tracking, task nudging, input telemetry"
echo "  .claude/skills/       /done /queue /nu /preview /code-audit /brainstorm"
echo "                        /recover /attention /pentest /idea-mining"
echo "  .claude/AGENTS.md     Skill registry"
echo "  .claude-memory/       Persistent agent memory"
echo "  scripts/cc-budget.sh  Token budget analytics"
echo "  CLAUDE.md             Project instructions template"
echo "  MAINTENANCE.md        Recurring task cadence"
echo "  REMINDERS.md          Follow-up tracker"
echo "  GOTCHAS.md            Operational workarounds log"
echo "  MILESTONES.md         Progress tracker"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md: fill in your project details"
echo "  2. Start a Claude Code session: hooks will auto-register"
echo "  3. Run 'bash scripts/cc-budget.sh summary' after a few sessions"
echo "  4. Create custom skills with '/nu <slug> <description>'"
echo ""
