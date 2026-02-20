# Agents & Skills

Registry of automated skills and their data files. Skills live in `.claude/skills/<slug>/SKILL.md`.

## Skills

| Name | Slug | Description | Cadence |
|------|------|-------------|---------|
| Commit | `/commit` | Stage diffs, generate commit message, commit | On-demand |
| Done | `/done` | Session completion check — flags unfinished work | On-demand |
| Queue | `/queue` | Capture current task to QUEUE.md for later | On-demand |
| New Skill | `/nu` | Scaffold a new skill from a description | On-demand |
| Preview | `/preview` | Serve a markdown file as live HTML on localhost | On-demand |

## Adding Skills

1. Create `.claude/skills/<slug>/SKILL.md`
2. Add the skill to the table above
3. Invoke with `/<slug>` in any session

## Skill Template

```markdown
# /slug — Skill Name

One-line description.

## Usage

`/slug <required-arg> [optional-arg]`

## Behavior

1. Step one
2. Step two
3. Step three

## Output

Describe what the skill produces.

## Notes

- Constraints, edge cases, or important details
```
