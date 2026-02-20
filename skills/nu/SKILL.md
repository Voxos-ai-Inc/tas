# /nu — Create New Skill

Create a new skill from a description.

## Usage

`/nu <slug> <description>`

## Behavior

1. Create directory `~/.claude/skills/<slug>/`
2. Create `SKILL.md` inside that directory based on the description provided
3. Follow the standard skill template:
   - Name and one-line description
   - Usage section with examples
   - Step-by-step behavior instructions
   - Output format specification
   - Notes / constraints
4. Report the new skill path and confirm it's ready to use
