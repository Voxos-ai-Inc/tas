---
name: attention
description: Audit the Golden Path Clarity score for frontend projects. Evaluates whether each UI funnels users into a single monetizable journey or leaks attention across competing paths.
---

# Attention Audit

Audit the Golden Path Clarity score for frontend projects. Evaluates whether each project's UI funnels users into a single monetizable journey or leaks attention across competing paths.

## Usage

- `/attention` — audit all frontend projects
- `/attention myapp` — audit a specific project
- `/attention app1 app2` — audit multiple specific projects

## Instructions

1. Read `CLAUDE.md` at the repo root to load the Golden Path Clarity rubric (scores 1-5). If the rubric isn't defined there, use the one below.
2. Parse arguments to determine which project(s) to audit. If no arguments, scan for all projects that have a frontend (`www/` or `src/` directory with React/HTML).
3. For each project:
   a. Read the project's `CLAUDE.md` to get the current declared score, golden path, and diagnosis.
   b. Explore the frontend source to map the actual current state:
      - Count nav items, CTAs, and distinct user flows per screen
      - Identify the golden path (single journey from entry to monetization)
      - Identify dead ends (pages with no conversion CTA or exit to external sites)
      - Identify competing paths (multiple CTAs of equal visual weight)
      - Calculate approximate attention ratio on key screens (actions available / desired action)
   c. Score the project using the rubric.
   d. Compare the new score to the declared score in the project's CLAUDE.md.
4. Present results as a summary table:

   | Project | Declared | Actual | Delta | Key Finding |
   |---------|----------|--------|-------|-------------|

5. For any project where Actual differs from Declared by >=1 point, flag it and describe what changed.
6. For each project, list one concrete improvement that would raise the score by 1 point.
7. Ask the user whether to update the project CLAUDE.md files with revised scores and diagnoses. Only update if approved.

## Scoring Rubric

| Score | Label | Criteria |
|-------|-------|----------|
| 5 | Razor | Every screen 1:1 attention ratio. One CTA. No dead ends. |
| 4 | Focused | Clear golden path. Secondary actions subordinate and loop back. |
| 3 | Diluted | Golden path competes with exploratory features of equal weight. |
| 2 | Fragmented | Multiple monetization paths of equal prominence. |
| 1 | Absent | No monetization funnel. Content without conversion. |

## Key Terms

- **Attention ratio**: things a user CAN do / things they SHOULD do. Ideal = 1:1.
- **Golden path**: single intended journey from entry to monetization event.
- **Funnel leakage**: branches where users exit the monetizable path.
- **Dead end**: page with no CTA leading toward conversion.
