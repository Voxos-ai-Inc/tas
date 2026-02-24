---
name: speak
description: Communication clarity drill. Pose prompts, score responses on clarity/concision/structure/fluency, track progress over time.
---

# speak

Interactive drill for practicing clear, concise verbal communication. Scores responses, tracks historical progress to disk, and increases difficulty over time.

## Usage

```
/speak              # Start a new drill session (or resume current)
/speak stats        # Show historical scores and trends
/speak review       # Review worst-scoring rounds and patterns
```

## Data

All progress is stored in `.claude/skills/speak/history.json`. The file persists across sessions so the drill builds on prior performance.

```json
{
  "sessions": [
    {
      "id": "2026-02-23T10:00:00Z",
      "rounds": [
        {
          "round": 1,
          "difficulty": "warm-up",
          "prompt": "What do you do?",
          "response": "...",
          "scores": {
            "clarity": 4,
            "concision": 3,
            "structure": 4,
            "fluency": 3
          },
          "composite": 3.5,
          "feedback": "...",
          "flagged_fillers": ["just", "kind of"],
          "fix": "Drop hedging qualifiers."
        }
      ],
      "session_avg": 3.5
    }
  ],
  "lifetime_avg": 3.5,
  "total_rounds": 1,
  "best_composite": 5.0,
  "worst_patterns": ["hedging", "filler 'like'"]
}
```

## Instructions

### Default (no subcommand) — Run the drill

1. **Load history**: Read `.claude/skills/speak/history.json`. If it doesn't exist, initialize an empty structure. Note the user's lifetime average, total rounds completed, and recurring weak patterns.

2. **Set difficulty**: Based on lifetime average:
   - Avg < 3.0: **warm-up** (simple, familiar prompts)
   - Avg 3.0-3.9: **standard** (requires structured thinking)
   - Avg 4.0-4.4: **hard** (abstract, ambiguous, or high-stakes scenarios)
   - Avg >= 4.5: **expert** (adversarial constraints, nested complexity, time pressure)

3. **Pose a prompt**: Choose from the prompt bank below (or generate a novel one matching the difficulty). Never repeat a prompt the user has already seen in history. Present it clearly.

4. **Wait for response**: The user types their answer as if speaking aloud.

5. **Score on 4 dimensions** (1-5 each):

| Dimension | 1 | 3 | 5 |
|-----------|---|---|---|
| **Clarity** | Confused or ambiguous | Understandable but requires re-reading | Instantly clear on first pass |
| **Concision** | Bloated, redundant | Some fat to trim | Every word earns its place |
| **Structure** | Stream of consciousness | Loose shape | Clean setup, point, evidence arc |
| **Fluency** | Riddled with fillers/hedges | A few slips | Zero filler, confident delivery |

6. **Flag fillers**: Identify any filler words or patterns:
   - Filler words: um, uh, like (non-comparative), so (sentence opener), basically, actually, kind of, sort of, I mean, you know, right?, honestly, literally, just (unnecessary)
   - Hedging: "I think", "I feel", "maybe", "probably", "it seems like"
   - False starts: restarted sentences, repeated openings
   - Throat-clearing: long wind-ups before the actual point

7. **Deliver feedback**: Show scores, composite (average of 4), flagged fillers, and ONE specific actionable fix for the next round. Keep feedback to 3-4 lines max.

8. **Save round**: Append the round to the current session in history.json.

9. **Continue**: Immediately pose the next prompt. Keep going until the user says stop or exits.

### `stats` subcommand

1. Read history.json.
2. Display:
   - Total rounds completed across all sessions
   - Lifetime composite average
   - Best single-round composite
   - Score trend (last 5 session averages)
   - Most common flagged fillers (top 3)
   - Most common weak dimension
   - Current difficulty tier

### `review` subcommand

1. Read history.json.
2. Find the 3-5 lowest-scoring rounds.
3. For each, show: the prompt, the user's response, scores, and what went wrong.
4. Synthesize: "Your recurring patterns are X, Y, Z. Focus on X first."

## Prompt Bank

### Warm-up (familiar, concrete)
- Someone at a dinner party asks: "What do you do?"
- A friend asks: "What's the best book you've read recently, and why?"
- Your teammate asks: "Why did you choose that approach for the last project?"
- A stranger in an elevator asks: "What's your company about?"

### Standard (requires structured thought)
- "What's the most important lesson you've learned from a failure?"
- "Explain why [current industry trend] matters to someone outside your field."
- "Your CEO asks for a 30-second update on your biggest project. Go."
- "Make the case for why remote work is better than in-office." (Or vice versa, your choice.)
- "A junior colleague asks: 'How do I get better at [your core skill]?' Give them one piece of advice."

### Hard (abstract, high-stakes, ambiguous)
- "You're pitching a VC. You have 60 seconds. What's your company and why now?"
- "A journalist asks: 'What's the biggest risk in your industry that nobody's talking about?'"
- "Explain a complex technical concept you know well to a smart 12-year-old."
- "Your board asks: 'Why should we double down on this strategy instead of pivoting?'"
- "Someone challenges your strongest-held professional belief. Defend it in 4 sentences."

### Expert (adversarial constraints, nested complexity)
- "Explain your company's value proposition without using any jargon or buzzwords."
- "You have 3 sentences to convince a skeptic that AI will change their industry. No hyperbole."
- "A hostile interviewer says: 'Your product is a solution looking for a problem.' Respond."
- "Summarize a year of work in 2 sentences for an investor who's about to leave."
- "You disagree with your boss in a meeting. State your position without hedging but without being combative."

## Conventions

- Always load history at the start and save after each round. The user expects continuity.
- Generate novel prompts when the bank is exhausted. Match difficulty tier. Vary domains (business, technical, personal, hypothetical).
- Composite score = mean of the 4 dimensions, rounded to 1 decimal.
- The 3-6 sentence constraint is a guideline communicated to the user, not scored punitively. If they nail it in 2 or need 7, focus on quality.
- Do NOT be generous with scores. A 3 is average. A 5 means broadcast-quality delivery. Most responses should land 3-4.
