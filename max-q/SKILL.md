---
name: Max Q
description: Prove 1:1 compliance between the static-fire blueprint and the git diff using parallel adversarial review sub-agents, then hand off to catch.
---

# Max Q

Max-Q's primary job is proving 1:1 spec compliance between the `static-fire`
blueprint and the actual `git diff`, covering every target file, signature,
type/schema/prop, edge case, error rule, constraint, and acceptance criterion.
Adversarial defect hunting is secondary. A `MAX-Q PASSED` verdict is the
certification that replaces manual human inspection: the user never has to read
the implementation.

**Standalone Mode:** Standalone mode requires a `static-fire` blueprint supplied
by the caller, including its authoritative `Blueprint criteria total: <N>`.
Never invoke `static-fire`, never derive a post-hoc blueprint from the diff, and
stop after the verdict. If no blueprint is supplied, halt and ask for one.
`catch`'s re-certification invocation is pipeline-only and read-only; review
against the supplied blueprint and report without dispatching fixes.

## Core Review Principles

1. **Spec Compliance First** — Every blueprint item must be matched to concrete
   diff evidence. No item may be PASS without evidence; an unverifiable item is
   FAIL.
2. **Zero-Human-Review Guarantee** — The verdict must certify the implementation
   without a human reading code. "Looks reasonable" is not a verdict; any
   unresolved item is FAIL.
3. **Unapproved Deviation Is a BLOCKER** — Any difference from the blueprint
   (extra export, changed signature, missing edge case, invented abstraction)
   blocks, even if the code appears to work.
4. **Adversarial Posture** — Actively try to break the diff; assume bugs exist
   until proven otherwise.
5. **Parallel Dimension Partitioning** — Fan out in one batch; never run a
   monolithic review.
6. **Diff-First Minimal Context** — Pass only the target diff slice, blueprint
   sections, and direct contracts.
7. **Actionable Findings Only** — No style nitpicks; only correctness, spec,
   security, performance, or requirement defects.

## Adaptive Review Scaling

- **Small changes (1–2 files, fewer than 50 lines):** Use one combined reviewer
  only if it covers all four review dimensions and every checklist row;
  otherwise use the full four-agent fan-out.
- **Multi-file or cross-module changes (3+ files or 50+ lines):** Engage the
  full four-dimension parallel fan-out.

## Execution Workflow

### Phase 1: Build the Compliance Checklist

From the blueprint, create exactly one row per stable criterion ID
(`U<n>.<m>`) emitted by `static-fire`. File, signature, schema, and edge-case
checks are evidence inside those rows, not extra rows.

- Use only the stable criterion IDs and `Blueprint criteria total: <N>` emitted
  by `static-fire`; `<N>` is the count of those criterion IDs.
- Never self-define the total or add/remove IDs; a mismatch is a stop condition.
- If any ID or the total is missing or mismatched, stop and escalate to
  `static-fire`; do not review.

**Review Set and Fingerprint:** The review set is the complete working-tree
change — `git diff HEAD` plus every untracked non-ignored file, each treated as
a full addition. `DIFF_FINGERPRINT` covers that full set with canonical path
ordering. The Blueprint Compliance Auditor must review untracked file contents,
not merely hash them.

Then spawn the review sub-agents in a single parallel batch:

1. **Sub-Agent 1 — Blueprint Compliance Auditor (Primary):**
   - **Focus:** Check the full checklist against the review set; each row
     PASS/FAIL with `file:line` evidence or "missing"; detect extra unapproved
     changes.
   - **Input:** Full blueprint + complete review set (tracked diff + untracked
     files) + liftoff receipts.

2. **Sub-Agent 2 — Correctness & Edge-Case Stress Tester:**
   - **Focus:** Logic flaws, null/empty/boundary handling, races, exceptions. It
     may not excuse spec violations.
   - **Input:** review set (tracked diff + untracked files) of modified
     implementation files + function signatures.

3. **Sub-Agent 3 — Contract & Integration Verifier:**
   - **Focus:** Cross-file imports/exports/signatures/schemas/props match the
     blueprint and each other; existing callers and regressions.
   - **Input:** review set across all modified files + shared contract/type
     files + caller grep results.

4. **Sub-Agent 4 — Security & Performance Reviewer:**
   - **Focus:** Injection, auth bypasses, secrets, N+1 queries, unbounded loops,
     blocking I/O.
   - **Input:** review set (tracked diff + untracked files) of modified
     implementation files.

**Optional Scaling Rule:** If the diff spans more than 8 files, partition the
compliance auditor by module so every checklist row is covered exactly once,
then aggregate.

### Phase 2: Sub-Agent Dispatch Payload

Use this exact template for each review sub-agent:

```text
Reviewer Role: <Blueprint Compliance | Correctness | Contracts | Security & Perf>
Blueprint Specification: <exact relevant blueprint sections; full blueprint for compliance>
Blueprint Criteria Total: <N>
Target Diff / Files: <exact file paths or diff hunk>
Compliance Checklist: <item ids + expected signature/behavior/criterion>
Output Constraint: Return ONLY this schema. If no issues exist, return STATUS: CLEAR.
- STATUS: CLEAR | ISSUES_FOUND
- SPEC_COMPLIANCE: <passed>/<N> (Blueprint Compliance reviewer only)
- DIFF_FINGERPRINT: <sha256 over git diff HEAD plus every untracked non-ignored file as a full addition, in canonical path order> (Blueprint Compliance reviewer only)
- CHECKLIST: <item id: PASS|FAIL; evidence: file:line | missing>
- FINDINGS: List of { severity: BLOCKER | MAJOR, file: <path:line>, issue: <1-sentence defect>, fix: <concrete instruction> } (max 150 words; checklist rows exempt)
```

### Phase 3: Triage & Verdict

1. Wait for all reviewers.
2. Declare `MAX-Q PASSED` only when `SPEC_COMPLIANCE` is `<N>/<N>` with evidence
   for every row, all reviewers return `CLEAR`, there are zero `BLOCKER`/`MAJOR`
   findings, there are zero unapproved deviations, and the reported
   `DIFF_FINGERPRINT` matches the complete current diff. Any missing or
   unverified row is a FAIL.
3. If defects exist, group by file ownership and spawn targeted fix sub-agents
   in parallel with the exact finding and relevant blueprint excerpt. After any
   remediation edit, rerun **all four reviewers** over the complete current diff
   and recompute `DIFF_FINGERPRINT`; prior verdicts are stale and cannot be
   reused. Cap remediation at two loops. After two loops without `CLEAR`, halt,
   report unresolved findings, and escalate; never declare PASS.
4. If the defect is a blueprint gap or ambiguity, escalate to `static-fire`
   replanning; do not patch by invention.
5. Hand off to `catch` with the blueprint, progress ledger, detected commands,
   authoritative total `N`, compliance matrix, final `DIFF_FINGERPRINT`, and
   receipts — telemetry only, no code dumps.
6. When `catch` invokes re-certification, run read-only: do not dispatch fix
   agents; report findings and stop.
