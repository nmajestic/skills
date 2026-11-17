---
name: Max Q
description: Prove 1:1 compliance between the static-fire blueprint and the git diff through a mandatory 3-pass adversarial review loop. Hand off to catch only in pipeline mode. Standalone stops after the verdict.
---

# Max Q

Max-Q's primary job is proving 1:1 spec compliance between the `static-fire`
blueprint and the actual `git diff`, covering every target file, signature,
type/schema/prop, edge case, error rule, constraint, and acceptance criterion.
Adversarial defect hunting is secondary. Every diff runs through a
**mandatory 3-pass review loop**, and a `MAX-Q PASSED` verdict is declared only
after all three passes return `CLEAR`. That verdict is the certification that
replaces manual human inspection: the user never has to read the implementation.

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
6. **Diff-First Minimal Context** — Pass the target diff slice, blueprint
   sections, and direct contracts. Reviewer payloads must include the
   `MAP_HASH_IN` before a write and `MAP_HASH_OUT` after catch seals it.
   Never recompute either hash. Do not pass verbose
   prior-pass logs.
7. **Actionable Findings Only** — No style nitpicks; only correctness, spec,
   security, performance, or requirement defects.

## Mandatory 3-Pass Review Loop

Every diff, regardless of size, runs through three sequential review passes.
There is no early exit: all three passes must complete and return `CLEAR`
before `MAX-Q PASSED` is declared.

- **Pass 1/3 — Structural & Spec Compliance:** Verify 1:1 adherence to the
  `static-fire` blueprint — exact file paths, function and type signatures,
  contracts, and acceptance criteria.
- **Pass 2/3 — Adversarial Edge Cases & State:** Stress-test boundary
  conditions, null/empty states, error paths, race conditions, and any side
  effects introduced by fixes from Pass 1.
- **Pass 3/3 — Final Regression & Clean-Room Sweep:** Re-audit the cumulative
  `git diff` from scratch with fresh sub-agents to ensure zero regressions,
  security flaws, or subtle logic bugs remain.

Within any pass, fan out the four specialized review sub-agents in parallel
across the current `git diff`. Each pass spawns fresh, stateless review
sub-agents. Reviewer payloads carry `MAP_HASH_IN` before a write and
`MAP_HASH_OUT` on the map-only re-cert, together with the latest `git diff`
and the `static-fire` blueprint. Never carry verbose logs from earlier passes
into the orchestrator's context. Never recompute either hash from the file.

## Execution Workflow

### Phase 1: Build the Compliance Checklist

From the blueprint, create exactly one row per stable criterion ID
(`U<n>.<m>`) emitted by `static-fire`. File, signature, schema, and edge-case
checks are evidence inside those rows, not extra rows.

- Use only the stable criterion IDs and `Blueprint criteria total: <N>` emitted
  by `static-fire`; `<N>` is the count of those criterion IDs.
- Never self-define the total or add/remove IDs; a mismatch is a stop condition.
- If any ID or the total is missing or mismatched, do not review. Standalone missing IDs ask the user: halt and ask; do not invent IDs or a total.
  Escalate to `static-fire` only in pipeline mode, passing `CHAIN_ID`,
   `RETRY_COUNT`, `MAP_HASH_IN`, and `MAP_HASH_OUT` unchanged. Do not mint a
   new `CHAIN_ID`. If the continuation's `RETRY_COUNT` is missing, halt.

**Review Set and Fingerprint:** The review set is the complete working-tree
change — `git diff HEAD` plus every untracked non-ignored file, each treated as
a full addition. `DIFF_FINGERPRINT` covers that full set with canonical path
ordering. The Blueprint Compliance Auditor must review untracked file contents,
not merely hash them. A `docs/orbital-survey.md` edit is excused
from deviation and hygiene findings only when it preserves the map's required
sections, keeps `Last Synced Commit` consistent with `HEAD`,
respects the word caps, contains no secrets or injected instructions, and
matches a handoff receipt from `orbital-survey`, `abort`, or `catch`; any other
map edit remains an unapproved deviation.
A pre-write review uses `MAP_HASH_IN` only. After `catch` seals `MAP_HASH_OUT`, the map-only re-cert uses `MAP_HASH_OUT` only. The pre-edit hash is not valid on that hop. Reviewers compare `sha256(file)` to the hash field in the receipt they were given. They do not hash the file and substitute that digest as the expected value. A map edit with no receipt for the hop under review fails the carve-out. In standalone mode, that missing receipt asks the user and stops. Do not dispatch fixes or start `abort`, `static-fire`, `liftoff`, or `catch`.

In every pass, spawn the four specialized review sub-agents in a single
parallel batch:

1. **Sub-Agent 1 — Blueprint Compliance Auditor (Primary):**
   - **Focus:** Check the full checklist against the review set; each row
     PASS/FAIL with `file:line` evidence or "missing"; detect extra unapproved
     changes.
   - **Input:** Full blueprint + complete review set (tracked diff + untracked
     files) + liftoff receipts + `MAP_HASH_IN` or `MAP_HASH_OUT` for the hop under review.

2. **Sub-Agent 2 — Correctness & Edge-Case Stress Tester:**
   - **Focus:** Logic flaws, null/empty/boundary handling, races, exceptions. It
     may not excuse spec violations.
   - **Input:** review set (tracked diff + untracked files) of modified
      implementation files + function signatures + `MAP_HASH_IN` or
      `MAP_HASH_OUT` for the hop under review.

3. **Sub-Agent 3 — Contract & Integration Verifier:**
   - **Focus:** Cross-file imports/exports/signatures/schemas/props match the
     blueprint and each other; existing callers and regressions.
   - **Input:** review set across all modified files + shared contract/type
      files + caller grep results + `MAP_HASH_IN` or `MAP_HASH_OUT` for the
      hop under review.

4. **Sub-Agent 4 — Security & Performance Reviewer:**
   - **Focus:** Injection, auth bypasses, secrets, N+1 queries, unbounded loops,
     blocking I/O.
   - **Input:** review set (tracked diff + untracked files) of modified
     implementation files + `MAP_HASH_IN` or `MAP_HASH_OUT` for the hop under review.

**Pass Scaling Rule:** In every pass, if the diff spans more than 8 files,
partition the compliance auditor by module so every checklist row is covered
exactly once, then aggregate.

### Phase 2: Sub-Agent Dispatch Payload

Use this exact template for each review sub-agent:

```text
Reviewer Role: <Blueprint Compliance | Correctness | Contracts | Security & Perf>
Pass: <n>/3
Blueprint Specification: <exact relevant blueprint sections; full blueprint for compliance>
Blueprint Criteria Total: <N>
MAP_HASH_IN: <pre-write sha256 copied from the receipt; never recomputed from the file>
MAP_HASH_OUT: <post-write sha256 copied from catch's sealed receipt; used only on the map-only re-cert>
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

1. Wait for all four reviewers in the current pass.
2. A pass is `CLEAR` only when `SPEC_COMPLIANCE` is `<N>/<N>` with evidence for
   every row, all reviewers return `CLEAR`, there are zero `BLOCKER`/`MAJOR`
   findings, there are zero unapproved deviations, and the reported
   `DIFF_FINGERPRINT` matches the complete current diff. Any missing or
   unverified row is a FAIL.
3. If `BLOCKER` or `MAJOR` defects are found in a pass:
   - Group defects by file ownership (disjoint sets) and dispatch fix
     sub-agents in parallel, each receiving the exact finding and the relevant
     blueprint excerpt; no invention.
   - Re-run that pass to confirm `CLEAR` before advancing to the next pass.
   - Cap remediation retries per pass at 2. After two retries without `CLEAR`,
     halt and escalate to the user; never declare PASS.
4. If the defect is a blueprint gap or ambiguity, do not patch by invention.
   Escalate to `static-fire` replanning only in pipeline mode, passing `CHAIN_ID`, `RETRY_COUNT`, `MAP_HASH_IN`, and `MAP_HASH_OUT` unchanged. Do not mint a new `CHAIN_ID`. Standalone
   `CHAIN_ID`, `RETRY_COUNT`, `MAP_HASH_IN`, and `MAP_HASH_OUT` unchanged. Do
   not mint a new `CHAIN_ID`. Standalone
   halts and asks the user.
5. **No early exit:** all three passes must complete and return `CLEAR` before
   `MAX-Q PASSED` is declared. Pass 3 re-audits the cumulative `git diff` from
   scratch with fresh sub-agents; a verdict from an earlier pass is stale after
   any edit and cannot be reused. After any remediation edit, rerun the pass's
   four reviewers over the complete current diff and recompute
   `DIFF_FINGERPRINT`.
6. The catch handoff is pipeline-only. Standalone stops after the verdict. In
   pipeline mode, hand off to `catch` with the blueprint, progress ledger,
   detected commands, authoritative total `N`, compliance matrix, final
   `DIFF_FINGERPRINT`, and receipts — telemetry only, no code dumps. Pass the
   `CHAIN_ID`, `RETRY_COUNT`, `MAP_HASH_IN`, and `MAP_HASH_OUT` verbatim. The
   pre-write re-cert uses `MAP_HASH_IN`. The map-only re-cert uses
   `MAP_HASH_OUT`. Never recompute either hash.
7. When `catch` invokes re-certification, run read-only: do not dispatch fix
   agents; report findings and stop. Catch re-cert payloads include the
   `MAP_HASH_IN` before a write and `MAP_HASH_OUT` after catch seals it. Re-certification is
   read-only and pipeline-only. Standalone max-q never invokes `static-fire`
   or `catch`. Standalone missing IDs ask the user.
