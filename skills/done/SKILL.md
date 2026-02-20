# /done — Session Completion Check

Review the entire conversation history and determine whether all work discussed in this session is complete.

## Steps

1. **Scan the conversation** for every task, request, or follow-up the user mentioned.
2. **For each item**, classify it as:
   - **Done** — code written, deployed, verified, or explicitly resolved
   - **In progress** — started but not finished
   - **Not started** — mentioned but never acted on
   - **Deferred** — explicitly punted to a future session
3. **Check for loose ends**:
   - Uncommitted changes (`git status`)
   - Running background processes or servers
   - Open TODO items created during this session
   - Pending deploys (code changed but not deployed)
   - MILESTONES.md or REMINDERS.md entries that need updating
4. **Present a summary table**:

| # | Item | Status |
|---|------|--------|
| 1 | ... | Done |
| 2 | ... | In progress |

5. **Give a clear verdict**:
   - If everything is done: "All clear — safe to close this session."
   - If items remain: list what's unfinished and ask whether to wrap them up now or defer to next session.
