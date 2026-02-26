# Contributing to TAS

Thanks for your interest in contributing. This document covers setup, coding standards, and how to submit changes.

## Setup

1. Fork and clone the repo
2. Create a test project directory with `git init`
3. Run `bash /path/to/tas/setup.sh --dry-run` to verify the installer works without side effects
4. Run `bash /path/to/tas/setup.sh` to install into your test project

## Coding Standards

### Shell scripts

- All `.sh` files must pass `shellcheck -x` with zero warnings
- Source shared utilities from `hooks/utils.sh` instead of duplicating helpers
- Use cross-platform functions (`_date_epoch`, `_stat_mtime`, `_readlink_f`) from `utils.sh` instead of GNU-only commands
- Use `$(_path "$file")` when passing paths to `jq` (handles Windows path conversion)
- Always quote variables: `"$VAR"`, not `$VAR`
- Use `set -euo pipefail` at the top of standalone scripts

### Python (bench/)

- Target Python 3.10+
- All files must pass `python -m py_compile`
- No external dependencies outside of `bench/requirements.txt`

### Markdown

- Use ATX-style headers (`#`, `##`, not underlines)
- One sentence per line in prose sections (makes diffs cleaner)
- No trailing whitespace

## Making Changes

1. Create a feature branch from `main`
2. Make your changes
3. Run the linter locally: `shellcheck -x hooks/*.sh scripts/*.sh setup.sh`
4. Test the setup script: `bash setup.sh --dry-run` in a fresh git repo
5. If you changed hooks, test them by running a Claude Code session with TAS installed
6. Commit with a descriptive message following conventional commits (`feat:`, `fix:`, `docs:`, `chore:`)
7. Open a pull request against `main`

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include a description of what changed and why
- If your change affects the setup script, test both `--dry-run` and actual install
- If your change adds a new skill, include the `SKILL.md` and update `templates/AGENTS.md`

## Reporting Issues

Open a GitHub issue with:
- What you expected to happen
- What actually happened
- Your OS and bash version (`bash --version`)
- Whether you're using Git Bash / MSYS2 on Windows

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
