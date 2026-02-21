---
name: brainstorm
description: Multi-angle parallel web research for strategic decisions. Launches 5 agents with different lenses, then synthesizes findings into an actionable recommendation.
---

## Usage

```
/brainstorm <strategic question or decision>
```

Examples:
- `/brainstorm what should we name our B2B SaaS product`
- `/brainstorm pricing strategy for an AI-powered developer tool`
- `/brainstorm should we launch on Product Hunt or do a private beta first`
- `/brainstorm best go-to-market motion for selling to 10-person engineering teams`

## What This Skill Does

Decomposes any strategic question into 5 research lenses, launches parallel agents to deeply investigate each angle via web search, then synthesizes all findings into a single structured recommendation with tradeoffs.

## Research Methodology

### Phase 1: Decompose the Question into 5 Lenses

Every strategic decision has multiple angles. Before launching agents, identify 5 lenses that collectively cover the decision space. The lenses should be orthogonal — each should surface insights the others won't.

**Default lens archetypes** (adapt to the specific question):

| # | Lens | What it answers |
|---|------|-----------------|
| 1 | **Best Practices & Patterns** | What do experts and established playbooks say? What patterns recur across successful companies? |
| 2 | **Competitive Landscape** | Who else has made this decision? What did they choose? What worked and what didn't? |
| 3 | **Saturation & Differentiation** | What's already crowded? Where is whitespace? What's overdone vs. underexplored? |
| 4 | **Psychology & Perception** | How will customers/users perceive each option? What does behavioral science say? |
| 5 | **Contrarian & Unconventional** | What would a contrarian do? What assumptions is everyone making that might be wrong? |

Tailor lenses to the question. For a naming decision, "Saturation" means search saturation. For a pricing decision, it means price-point crowding. For a launch strategy, it means channel saturation.

### Phase 2: Launch 5 Parallel Agents

Launch all 5 agents simultaneously using `Task` tool with `subagent_type: general-purpose`.

Each agent's prompt MUST:
1. State the full context of the product/company (copy relevant context from the conversation)
2. Clearly define which lens this agent owns
3. Instruct the agent to perform multiple web searches (not just one)
4. Demand specifics: names, numbers, examples, URLs — no hand-waving
5. Request a structured output with clear sections

**Agent prompt template:**

```
You are researching a strategic decision.

Context: [PRODUCT/COMPANY CONTEXT]

The decision: [QUESTION]

Your research lens: [LENS NAME] — [LENS DESCRIPTION]

Conduct 5-10 web searches to deeply investigate this angle. Do NOT search for generic listicles. Search for specific companies, case studies, data points, and expert analyses.

For every claim, provide the source. For every recommendation, provide evidence.

Return a structured analysis with:
1. Key findings (bullet points with sources)
2. Patterns or frameworks discovered
3. 5-10 specific recommendations or options (if applicable)
4. Risks and tradeoffs
```

### Phase 3: Synthesize

After all 5 agents complete, synthesize their findings into a single recommendation. The synthesis MUST include:

1. **The consensus** — What do multiple lenses agree on?
2. **The tensions** — Where do lenses contradict each other? What tradeoffs exist?
3. **Top recommendations** — Ranked list of options with pros/cons from multiple angles
4. **The contrarian take** — What one insight from the unconventional lens challenges the consensus?
5. **Decision criteria** — A simple framework the user can apply to make the final call

## Output Format

```markdown
## [Question] — Research Synthesis

### Key Finding
[The single most important structural insight]

### Consensus Across Lenses
- [Finding that 3+ lenses agree on]
- [Finding that 3+ lenses agree on]

### Top Recommendations

| Option | Strengths | Risks | Lenses Supporting |
|--------|-----------|-------|-------------------|
| ... | ... | ... | ... |

### Tensions & Tradeoffs
- [Where lens A and lens B disagree, and why]

### Contrarian Take
[The one unconventional insight that challenges the mainstream view]

### Decision Criteria
[A simple 3-5 question framework the user can apply]
```

## Critical Rules

1. **All 5 agents launch in the SAME message.** Parallel execution is mandatory. Never serialize.
2. **Each agent does 5-10 web searches minimum.** One search per agent is not enough depth.
3. **Context must be complete in each agent prompt.** Agents don't share memory. Every agent needs the full product/company context to give relevant advice.
4. **Synthesis happens AFTER all agents complete.** Do not begin synthesis until every agent has returned.
5. **No generic advice.** Every recommendation must be grounded in specific evidence, examples, or data found during research.
6. **Present tensions, don't resolve them.** The user makes the final call. Surface the tradeoffs clearly so they can decide with full information.
7. **Sources required.** Every agent must cite URLs for key claims.
