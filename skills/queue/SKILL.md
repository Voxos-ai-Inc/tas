# /queue — Queue Task for Later

Queue the current task and its details to QUEUE.md for later execution.

## Usage

Invoke with `/queue` after discussing a task with the user. This captures the task details so another session can pick it up later.

## Behavior

1. Identify the most recently discussed task from the conversation
2. Extract key details: what needs to be done, relevant files/paths, any constraints or preferences mentioned
3. Append the task to `QUEUE.md` in the repository root (create if it doesn't exist)
4. Format as a structured entry with timestamp and clear description

## QUEUE.md Format

```markdown
## Queued Tasks

### [TIMESTAMP] Task Title
**Status:** Pending
**Context:** Brief summary of what was discussed
**Details:**
- Specific requirements
- Relevant files/paths
- Any constraints or preferences

---
```

## Notes

- Each task entry should be self-contained so a fresh session can understand it
- Include enough context that no follow-up questions are needed
- Mark entries with `**Status:** Pending` initially
- When a task is picked up, update status to `In Progress` or `Completed`
