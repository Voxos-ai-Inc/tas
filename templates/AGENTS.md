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
| Code Audit | `/code-audit` | Recursive code-path audit across all user journeys | On-demand |
| Brainstorm | `/brainstorm` | 5-lens parallel web research for strategic decisions | On-demand |
| Recover | `/recover` | Find and resume orphaned sessions after crashes | On-demand |
| Attention | `/attention` | Audit frontend golden-path clarity scores | On-demand |
| Hypothesis | `/hypothesis` | Hypothesis-driven A/B testing for code changes | On-demand |
| Pen Test | `/pentest` | External penetration test reconnaissance | On-demand |
| Speak | `/speak` | Communication clarity drill with scoring | On-demand |
| HN Pain Points | `/hn-pain-points` | Scrape HN for trending unsolved pain points | Weekly |
| Idea Mining | `/idea-mining` | Bulk ideation with web-search novelty filtering | On-demand |
| Locales | `/locales` | Regenerate i18n translations via i18n-locale-gen | On-demand |

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
