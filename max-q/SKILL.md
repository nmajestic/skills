---
name: Max Q
description: Adversarially stress-test code changes with parallel specialized review sub-agents before final audit and commit.
---

# Max Q

Stress-test all code changes before final audit and commit (`catch`). Deploy
specialized, adversarial review sub-agents in parallel to expose logic bugs,
edge cases, contract mismatches, and security/performance regressions without
bloating the orchestrator's context window.

**Standalone Mode:** When invoked directly without a prior `static-fire`
acceptance criteria block, inspect the current `git diff` (staged or unstaged)
and treat the user-stated intent as the acceptance criteria.

## Core Review Principles

1. **Adversarial Posture** — Reviewers must actively try to break the diff.
   Assume bugs exist until proven otherwise. Do not approve changes with vague
   praise.
2. **Parallel Dimension Partitioning** — Never run a single monolithic review.
   Fan out separate sub-agents simultaneously in one batch—each focused on a
   distinct failure mode or file slice.
3. **Diff-First Minimal Context** — Pass each review sub-agent only the
   `git diff` of its target files, the original `static-fire` acceptance
   criteria, and any directly imported contracts. Never dump the entire
   repository into context.
4. **Actionable Findings Only** — Suppress stylistic nitpicks (handled by
   linters in `catch`). Flag only concrete defects that affect correctness,
   edge cases, security, performance, or requirements.

## Adaptive Review Scaling

- **Small changes (1–2 files and fewer than 50 lines):** Use a single combined
  review sub-agent covering all four dimensions.
- **Multi-file or cross-module changes (3+ files or 50+ lines):** Engage the
  full four-dimension parallel fan-out.

## Execution Workflow

### Phase 1: Parallel Review Fan-Out

Apply the Adaptive Review Scaling above, then spawn the review sub-agents in a
**single parallel batch** (one combined reviewer for small changes, or all four
for multi-file changes):

1. **Sub-Agent 1 — Correctness & Edge-Case Stress Tester:**
   - **Focus:** Logic flaws, off-by-one errors, null/undefined handling, empty
     states, race conditions, and unhandled exceptions in the diff.
   - **Input:** `git diff` of modified implementation files + function
     signatures.

2. **Sub-Agent 2 — Contract & Integration Verifier:**
   - **Focus:** Cross-file compatibility. Verify that imports, exports, type
     signatures, API payloads, and database schemas match across all files
     touched in `liftoff`.
   - **Input:** `git diff` across all modified files + shared contract/type
     files.

3. **Sub-Agent 3 — Acceptance Criteria & Regression Auditor:**
   - **Focus:** Verify every requirement from the `static-fire` plan is
     actually implemented, and check whether modified shared utilities break
     existing callers.
   - **Input:** `static-fire` plan/criteria (or user-stated intent when
     standalone) + `git diff` + grep results of callers.

4. **Sub-Agent 4 — Security & Performance Reviewer:**
   - **Focus:** Injection vectors, auth/permission bypasses, leaked secrets,
     N+1 queries, unbounded loops, or blocking I/O on hot paths.
   - **Input:** `git diff` of modified implementation files.

*(Optional Scaling Rule: If the diff spans > 8 files, partition Sub-Agent 1 by
module/directory so each sub-agent reviews at most 3–4 files.)*

### Phase 2: Sub-Agent Dispatch Payload

Use this exact payload for each review sub-agent:

```text
Reviewer Role: <Correctness | Contracts | Requirements | Security & Perf>
Target Diff / Files: <exact file paths or diff hunk>
Acceptance Criteria: <from static-fire, or user-stated intent when standalone>
Output Constraint: Return ONLY structured findings using this exact schema. If no issues exist, return STATUS: CLEAR.
- STATUS: CLEAR | ISSUES_FOUND
- FINDINGS: List of { severity: BLOCKER | MAJOR, file: <path:line>, issue: <1-sentence defect>, fix: <concrete fix instruction> } (Max 150 words total).
```

### Phase 3: Triage & Remediation Loop

1. Wait for all parallel review sub-agents to return.
2. **If all return `CLEAR`:** Declare `MAX-Q PASSED` and immediately transition
   to `catch`.
3. **If any return `BLOCKER` or `MAJOR` findings:**
   - Group defects by file ownership (disjoint sets).
   - Spawn targeted fix sub-agents in parallel (1 per affected file) passing
     only the specific finding and fix instruction.
   - Re-run only the failed review dimension on the updated diff (max 2
     remediation loops before escalating to the user).
