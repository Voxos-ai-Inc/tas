# Skill: HN Pain Point Analysis

Scrape recent Hacker News posts and comments to identify trending unsolved pain points, frustrations, and unmet needs in the tech community.

**Recommended cadence:** Weekly (e.g., Sunday evening). HN's front page turns over every 12-24h but comment threads stay active ~48h. Weekly captures ~300 unique stories with minimal redundancy.

## Instructions

1. **Fetch the current front page, Ask HN, and newest comments in parallel:**
   - `https://news.ycombinator.com/` — top 30 stories with item IDs
   - `https://news.ycombinator.com/ask` — Ask HN stories (highest pain-point density)
   - `https://news.ycombinator.com/newcomments` — recent comments for quick signal

2. **Identify high-signal threads** — prioritize these types:
   - "Ask HN" threads about tools, workflows, or frustrations
   - Threads with titles containing: pain, broken, frustrat, hate, struggle, alternative, replaced, dying, dead, insane, wrong, bad, fail, rant, unpopular opinion
   - "What are you working on" threads (reveals gaps people are trying to fill)
   - "Show HN" threads with heavy criticism in comments
   - Any thread with 100+ comments (controversial = pain)

3. **Deep-scrape 10-15 of the most pain-point-rich threads** by fetching their full comment pages in parallel. For each thread, extract:
   - Specific frustrations and complaints (direct quotes where possible)
   - What tools/products are criticized and why
   - What people wish existed
   - Workarounds people describe (signals unmet need)

4. **Synthesize into a trend report** written to `HN_PAIN_POINTS.md` in the repo root. The report must include:

   ### Structure
   - **Date and scope** — when scraped, how many threads analyzed
   - **Numbered pain points ranked by signal strength** (how many threads/comments mention it, intensity of frustration)
   - For each pain point:
     - Clear problem statement
     - Specific sub-problems with quoted evidence
     - Who has this problem
     - What exists today and why it fails
     - **Opportunity** — what a solution would look like
   - **Summary table** ranking pain points by estimated market size and intensity
   - Mark any pain points that appeared in previous reports as **recurring** vs **new this week**

   ### Quality bar
   - Minimum 5 distinct pain points, target 7-10
   - Each must have evidence from at least 2 separate threads/comments
   - Avoid vague complaints — focus on specific, actionable problems
   - Distinguish between "annoying" (low value) and "blocking" (high value) pain points

5. **Deduplification with previous runs:**
   - Before writing, check if `HN_PAIN_POINTS.md` already exists
   - If it does, read it and compare findings
   - Flag which pain points are **new this week**, **recurring** (appeared before), or **resolved/fading**
   - Keep a rolling "Recurring Pain Points" section at the bottom that tracks persistence across weeks
   - Archive the previous report's date-specific findings under a `## Archive` collapsible section if desired, or simply overwrite with the new week's data while preserving the recurring tracker

6. **Output:** Overwrite `HN_PAIN_POINTS.md` with the new report. Print a 3-5 line summary to the user highlighting the top 3 pain points and any notable new entries.
