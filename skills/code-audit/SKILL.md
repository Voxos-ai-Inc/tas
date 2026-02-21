---
name: code-audit
description: Recursive code-path audit. Traces all user journeys through a project, finds dead ends, contract mismatches, security gaps, and convention violations. Produces a prioritized issue list and fix DAG.
---

## Usage

```
/code-audit <project> [--branch <name>] [--focus <area>]
```

Examples:
- `/code-audit myapp`
- `/code-audit backend --focus billing`
- `/code-audit frontend --branch feature/new-checkout`

## Instructions

### 1. Locate the project

Resolve `<project>` to its root directory. Verify it exists. Read the project's `CLAUDE.md` or `README.md` if present for architecture context.

### 2. Map the surface area

Launch an **Explore agent** (thoroughness: very thorough) to build a comprehensive map of all user-facing entry points:

- **Frontend routes/pages** — React Router, App.tsx, all page components
- **API endpoints** — handler/router file, all route modules, auth types
- **Pipeline/worker entry points** — background tasks, queue consumers, cron jobs
- **Infrastructure entry points** — CDN, serverless functions, scheduled events

The agent must return: every route with its handler function, auth type, and downstream service calls.

### 3. Identify user journeys

From the surface map, identify distinct user journeys. Standard journey categories:

| Category | What to look for |
|----------|-----------------|
| **Auth & Onboarding** | Register, login, OAuth, password reset, session management |
| **Core CRUD** | Create/read/update/delete of the project's primary entities |
| **Pipeline/Processing** | Any async processing (background jobs, queue consumers) |
| **Publishing/Distribution** | Making content public, sharing, notifications |
| **Social/Discovery** | User interactions (votes, comments, bookmarks), public feeds |
| **Billing/Payments** | Checkout, tier enforcement, credits, usage tracking |
| **AI/LLM Features** | Chat, TTS, refinement, any LLM API calls |
| **File Management** | Uploads, artifacts, presigned URLs, storage operations |

Skip categories that don't apply to the target project.

### 4. Launch parallel audit agents

For each identified journey, launch a **general-purpose agent** in the background. Each agent's prompt must include:

```
You are a code path auditor for the <project> project.
Trace the <JOURNEY NAME> user journey through the actual code.
Do NOT write any code -- only read and analyze.

## Code paths to trace:
[list specific paths for this journey]

## For each path, check:
- Does the frontend call match what the API handler expects? (request body shape, URL params)
- Does the API handler validate input? What happens with missing/malformed fields?
- Is error handling complete? (what errors bubble to the user vs get swallowed?)
- Are there dead ends? (frontend references something the backend doesn't implement, or vice versa)
- Authorization: does every write endpoint verify ownership/permissions?
- Race conditions: concurrent operations, read-then-write patterns without atomic guarantees
- Security: secrets handling, input sanitization, CORS, auth enforcement

## Output format:
Produce a structured report with:
1. **Path Trace**: For each step: Frontend Component -> API Endpoint -> Handler -> Service -> DB Operation
2. **Issues Found**: Each with severity (Critical/High/Medium/Low), file:line, description
3. **Metrics**:
   - Files involved in this path
   - Error handling coverage (% of operations with error handling)
   - Input validation coverage (% of fields validated)
   - Authorization check coverage (% of write endpoints that verify ownership)
   - Dead ends found (count)
4. **Dead End Details**: Any route/function referenced but not implemented
```

### 5. Collect results

Wait for all agents to complete. For each, extract:
- Issue count by severity
- Files involved
- Coverage metrics
- Dead ends

### 6. Synthesize unified report

Produce a single document at `CODE_PATH_AUDIT.md` in the project root with:

#### Header
```markdown
# <Project> Code Path Audit -- <date>
```

#### Exploration tree
ASCII tree showing all traced journeys with file counts and issue counts.

#### Branch metrics table
| Branch | Files | Crit | High | Med | Low | Error Handling | Auth Coverage | Dead Ends |

#### All issues by severity
Tables for Critical, High, Medium, Low. Each row: #, Branch, File, Line, Issue, Impact.

#### Cross-cutting patterns
Themes that appear across multiple branches (e.g., missing input validation, phantom records, race conditions).

#### Dead ends
All dead code, unimplemented references, vestigial features.

#### Fix DAG
Dependency graph for parallel execution:
1. Group issues by file (agents can't edit the same file concurrently)
2. Identify cross-file dependencies (e.g., service layer must be fixed before route layer)
3. Assign work units (A, B, C...) with file scope, issue list, severity, and estimated complexity
4. Draw the DAG showing which units can run in parallel vs must be sequential
5. Provide a priority-ordered serial fallback

### 7. Present results

Show the user:
- Total issue counts by severity
- Top 5 most urgent issues (production impact)
- The fix DAG with parallelization plan
- Location of the full report file

## Conventions

- **Severity scale**: Critical = guaranteed crash or compliance violation. High = security gap, data loss risk, broken flow. Medium = convention violation, edge case, degraded UX. Low = code smell, minor inconsistency, cosmetic.
- **Auth coverage**: Every write endpoint must verify caller identity and resource ownership. Flag gaps as High.
- **Race conditions**: Any read-then-write without atomic guarantees is High.
- **Dead ends**: Code that exists but is unreachable, uncallable, or has no consumer. Flag as Medium unless it causes user-facing breakage (then Critical).
