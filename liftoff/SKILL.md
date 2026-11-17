---
name: Liftoff
description: Orchestrate execution of an approved plan via maximum sub-agent parallelization, fanning out atomic tasks in dependency waves with lean context.
---

# Liftoff

Orchestrate the execution of an approved implementation plan using **maximum
sub-agent parallelization**. Decompose work into the smallest possible
independent units and fan out as many concurrent sub-agents as possible per
wave while keeping the orchestrator's context window lean.

**Standalone Mode:** When invoked directly without a prior `static-fire` report,
treat the user-provided spec or prompt as the plan and proceed. When chained,
consume the `static-fire` acceptance criteria and detected commands.

## Core Orchestration Principles

1. **Never Implement Directly** — As the orchestrator, do not write code, read
   large files, or run verbose test logs in your own context. Delegate 100% of
   file operations and shell executions to sub-agents.
2. **Maximum Fan-Out (1 File / 1 Unit = 1 Sub-Agent)** — Never bundle multiple
   independent files or modules into a single sub-agent if they can be built
   concurrently. Split tasks down to the finest atomic granularity (e.g.,
   1 component = 1 sub-agent, 1 test file = 1 sub-agent, 1 API route =
   1 sub-agent) and spawn the entire wave in a single parallel tool-call batch.
3. **Strict File-Ownership Partitioning** — Every concurrent sub-agent in a
   wave must own a strictly disjoint set of files. Two sub-agents in the same
   wave must never write to the same file.
4. **Minimal Context Injection** — Pass each sub-agent only its owned file
   path(s), exact shared type/interface contracts, and acceptance criteria.
   Never pass full conversation history or unrelated repo files.
5. **Compact Handoffs (< 150 words)** — Sub-agents must return only a terse
   structured receipt—never full file contents or raw terminal dumps.

## Adaptive Fan-Out Scaling

- **Small changes (1–2 files and fewer than 50 lines):** Use a single worker
  sub-agent; do not spin up a full wave.
- **Multi-file or cross-module changes (3+ files or 50+ lines):** Engage full
  maximum parallel fan-out across dependency waves.

## Execution Workflow

### Phase 1: Fine-Grained Decomposition & Wave Planning

Apply the Adaptive Fan-Out Scaling above, then break the plan (from
`static-fire`, or the user's spec when standalone) into atomic tasks grouped
into dependency waves:

- **Wave 0 (Contracts First — if needed):** If multiple parallel agents need
  shared types, schemas, or interfaces that do not exist yet, spawn 1 sub-agent
  to write the shared contract file first so all Wave 1 agents can build
  against it simultaneously without conflicts.
- **Wave 1 (Max-Width Parallel Fan-Out):** Spawn all independent implementation
  tasks simultaneously in one batch (e.g., individual modules, routes, UI
  components, database queries, and unit test files).
- **Wave 2+ (Integration & Wiring):** Spawn parallel sub-agents for tasks that
  import or wire together Wave 1 outputs (e.g., barrel exports, router
  registration, main entry points).
- **Final Wave (Parallel Verification):** Simultaneously dispatch separate
  sub-agents for independent checks (e.g., Sub-Agent A runs unit tests,
  Sub-Agent B runs type-checking/linting, Sub-Agent C runs build verification).

### Phase 2: Sub-Agent Dispatch Payload

Dispatch every sub-agent in the active wave simultaneously using this strict
template:

```text
Task ID: <wave>.<number>
Objective: <1-sentence imperative goal>
Owned Files (Read/Write): <exact file path(s) — strictly disjoint from sibling agents>
Reference Contracts (Read-Only): <exact shared types, schemas, or signatures needed>
Acceptance Criteria: <specific testable conditions>
Output Constraint: Return ONLY:
- STATUS: PASS | FAIL
- FILES_MODIFIED: <list>
- EXPORTS_CHANGED: <new/updated function or type signatures, or "none">
- ERRORS: <concise error summary if FAIL, else "none">
```

### Phase 3: Synchronization & Recovery

1. Wait for all sub-agents in the current wave to complete.
2. If any sub-agent reports `FAIL`, immediately spawn a targeted fix sub-agent
   for only that failed file while keeping intact work untouched.
3. Once the Final Verification wave returns `PASS` across all checks, hand off
   to `max-q` for adversarial review. Do not stage or commit here; `catch`
   owns all landing and commit.
