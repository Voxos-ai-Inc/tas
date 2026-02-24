# Idea Mining

Generate large batches of creative ideas (headlines, taglines, product concepts, etc.), then systematically validate their novelty via web search, narrowing to only those that don't already proliferate online.

## Trigger

User asks to brainstorm, ideate, or "mine" ideas — especially when they want volume + novelty filtering. Keywords: "idea mine", "brainstorm and validate", "fresh ideas", "what doesn't exist yet", "novel headlines", "unique concepts".

## Arguments

- **topic** (required): The domain or format (e.g., "clickbait product headlines for 2030", "SaaS taglines for developer tools", "startup names for AI fitness")
- **count** (optional, default 100): How many raw ideas to generate before filtering
- **target** (optional, default 30): How many fresh ideas to return after novelty filtering
- **category_tags** (optional): Comma-separated categories to organize ideas (e.g., "AI, Health, Finance, Space")

## Persistence

All results are cached in `~/.claude/idea-mining/` to avoid redundant web searches:

- **`registry.jsonl`** — append-only ledger of every idea ever evaluated. Each line is a JSON object:
  ```json
  {"id": "sha256-first-8", "idea": "The full headline text", "topic": "clickbait headlines 2030", "category": "AI", "verdict": "fresh|saturated|semi-saturated", "searched_at": "2026-02-08T...", "search_queries": ["query1", "query2"], "notes": "Why it was rated this way"}
  ```
- **`runs/YYYY-MM-DD_HHmmss.json`** — full snapshot of each run (raw ideas, search results, final curated list)
- **Before searching**, always load `registry.jsonl` and skip any idea whose core concept (fuzzy match on idea text) was already evaluated. Report how many cache hits were found.

## Workflow

### Phase 1: Generate Raw Ideas
1. Ask the user for the topic if not provided as an argument.
2. Generate `count` ideas organized by category. Use punchy, varied formats (first-person testimonials, stat-driven claims, provocative inversions, "just happened" framings).
3. Present the full list to the user for review before proceeding.

### Phase 2: Check Persistence Cache
1. Read `~/.claude/idea-mining/registry.jsonl` (create if missing).
2. For each generated idea, check if a substantially similar concept was already evaluated.
3. Report: "X ideas found in cache (Y fresh, Z saturated). Searching the remaining N."

### Phase 3: Novelty Search (Parallel)
1. Group uncached ideas into batches of 10-20 by category.
2. Launch parallel search agents (subagent_type: `general-purpose`) — one per batch.
3. Each agent searches the web for the core concept of each idea and rates it:
   - **FRESH** — no similar headlines, articles, or products found with this framing
   - **SATURATED** — many articles/products already use very similar framing
   - **SEMI-SATURATED** — underlying concept is covered but specific angle is novel
4. Append every result to `registry.jsonl` as it comes back.
5. Save the full run to `runs/YYYY-MM-DD_HHmmss.json`.

### Phase 4: Curate Final List
1. Combine cached fresh results + newly confirmed fresh results.
2. If more than `target` fresh ideas exist, curate down by selecting:
   - Broadest category coverage
   - Strongest click-worthiness / viral potential
   - Most novel framing (prefer "FRESH" over "SEMI-SATURATED")
3. Present the final `target` ideas as a numbered list, organized by category.
4. Include a brief note on what was cut and why.

## Output Format

```
## [Topic] — [target] Fresh Ideas (from [count] generated)

**Cache hits:** X ideas previously evaluated (Y fresh, Z saturated)
**New searches:** N ideas searched across M parallel agents
**Fresh rate:** X% of ideas were novel

### [Category 1]
1. "Headline text here"
2. "Headline text here"

### [Category 2]
3. "Headline text here"
...

---
**Cut from final list:** Brief note on ideas that were fresh but didn't make the cut.
**Run saved to:** ~/.claude/idea-mining/runs/YYYY-MM-DD_HHmmss.json
```

## Example Invocation

```
/idea-mining topic="dystopian product names for 2035" count=50 target=20 category_tags="AI,Biotech,Social,Finance"
```

## Notes

- The registry is append-only — never delete past evaluations. Ideas can be re-evaluated by passing `--force-refresh`.
- Semi-saturated ideas count as "fresh enough" for the final list if not enough fully fresh ideas exist.
- Search agents should search for the *concept*, not the exact headline text (e.g., search "AI negotiates salary autonomously" not the literal headline string).
- When the user runs this skill again on the same or overlapping topic, cache hits dramatically reduce cost and latency.
