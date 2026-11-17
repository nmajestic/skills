---
name: Liftoff
description: Execute an approved static-fire blueprint verbatim with maximum sub-agent parallelization and a zero-read orchestrator that tracks structured PASS/FAIL receipts.
---

# Liftoff

Liftoff is blind, mechanical execution of the `static-fire` blueprint, using
**maximum sub-agent parallelization**. The orchestrator is a scheduler, not an
implementer or reviewer: it never reads implementation diffs or file contents.
The blueprint is authoritative and workers have no architectural authority.

**Standalone Mode:** When invoked directly without a prior `static-fire`
blueprint, treat the user-provided spec as the blueprint. If that spec is not
blueprint-grade or leaves architectural choices open, ask the user and stop;
never invent decisions. Do not route to `static-fire` in standalone mode. In
standalone mode, execute the provided blueprint and stop after the final
verification wave; do not hand off to `max-q`. Pipeline mode hands off.

## Zero-Read Orchestration

The orchestrator schedules work and validates receipts; it does not inspect the
codebase.

1. **Blueprint Is the Only Spec** — The plan from `static-fire` is the complete
   contract. No design work happens here.
2. **Never Read Implementation** — The orchestrator must not open, cat, diff,
   or inspect implementation file contents or diffs at any point during or
   after liftoff. Its context stays limited to the blueprint, dispatch
   receipts, and command telemetry.
3. **Receipt-Only Progress** — Progress is tracked solely through structured
   PASS/FAIL receipts mapped to blueprint units and criteria. A unit is
   complete only when its receipt has `STATUS: PASS`, `BLUEPRINT_MATCH: PASS`,
   every criterion PASS, and `DEVIATIONS: none`.
4. **No Architectural Authority** — Sub-agents execute the blueprint verbatim
   and may not invent abstractions.
5. **Progress Ledger** — Keep a minimal table, updated only from receipts:

   | Unit | Owned files | Blueprint criteria | Receipt status |
   | --- | --- | --- | --- |
   | `<unit id>` | `<exact paths>` | `<criterion ids>` | `PENDING` |

## Blind Mechanical Execution (Sub-Agent Contract)

Every worker sub-agent operates under the same contract.

- **Required:** Use the exact paths, names, signatures, schemas, props, edge
  cases, and error rules in the blueprint. Modify only owned files. Report any
  deviation.
- **Forbidden:** Choose libraries, patterns, or layers; add files,
  dependencies, or exports not in the blueprint; rename; change signatures or
  schemas; refactor beyond scope; "improve" behavior; resolve ambiguity by
  judgment.
- **Ambiguity rule:** If the blueprint is incomplete, contradictory, or
  unimplementable, stop and return `STATUS: FAIL` with `BLOCKED: <gap>`; never
  guess or invent.

Any unapproved abstraction or deviation is an automatic `FAIL` and a `max-q`
`BLOCKER`.

## Adaptive Fan-Out Scaling

- **Small changes (1–2 files and fewer than 50 lines):** Use one worker
  sub-agent; do not spin up a full wave.
- **Multi-file or cross-module changes (3+ files or 50+ lines):** Use full
  parallel fan-out across dependency waves.

## Execution Workflow

### Phase 1: Fine-Grained Decomposition & Wave Planning

Before starting a wave, confirm every unit can be derived from the blueprint
without invention. If the blueprint is incomplete or contradictory, return
`STATUS: FAIL` with `BLOCKED: <gap>` and start no wave. Then group the units
into dependency waves:

- **Wave 0 (Contracts First — only when declared):** Only when the blueprint
  declares a shared contract unit that parallel agents need, dispatch one
  sub-agent for that unit before the rest.
- **Wave 1 (Max-Width Parallel Fan-Out):** Dispatch all independent units
  simultaneously in one batch.
- **Wave 2+ (Integration & Wiring):** Dispatch units that import or wire
  together earlier wave outputs.
- **Final Wave (Parallel Verification):** Dispatch parallel verification units
  as defined by the blueprint.

### Phase 2: Sub-Agent Dispatch Payload

Dispatch every sub-agent in the active wave simultaneously using this exact
template:

```text
Task ID: <wave>.<number>
Blueprint Unit: <exact unit/section from static-fire>
Objective: <1-sentence imperative from the blueprint>
Owned Files (Read/Write): <exact file path(s) — strictly disjoint from sibling agents>
Blueprint Excerpt (Authoritative): <exact signatures, schemas, props, edge cases, and error rules for this unit>
Acceptance Criteria: <exact machine-verifiable criteria from the blueprint>
Incoming CHAIN_ID: <id or new>
Incoming RETRY_COUNT: <n or none>
Execution Rule: Implement verbatim. Do not add files, dependencies, exports, abstractions, or behavior not in the blueprint. If the blueprint is incomplete or contradictory, stop and return STATUS: FAIL with BLOCKED: <gap>.
Output Constraint: Return ONLY:
- UNIT: <U<n>>
- STATUS: PASS | FAIL
- BLUEPRINT_MATCH: PASS | FAIL
- FILES_MODIFIED: <list>
- EXPORTS_CHANGED: <must match the blueprint exactly, or "none">
- CRITERIA: <criterion id: PASS|FAIL — evidence: <command/assertion + exit code | file:line>; ...>
- DEVIATIONS: none | <any unapproved difference; any entry forces FAIL>
- BLOCKED: none | <blueprint gap or unimplementable requirement>
- CHAIN_ID: <incoming id>
- RETRY_COUNT: <incoming + 1>
- ERRORS: <concise summary if FAIL, else "none">
```

Every criterion needs evidence; a bare PASS without evidence is invalid. Any
non-none `BLOCKED` forces `STATUS: FAIL`. A missing `Incoming RETRY_COUNT` means
0 only when `CHAIN_ID` is new. A continuation with the same `CHAIN_ID` and a
missing count halts. Do not reset the cap to 0. Set returned `RETRY_COUNT` to
incoming + 1. Reject a lower count. Halt before dispatching an attempt above
2. On a standalone retry cap or `BLOCKED` receipt, ask the user and stop. Do
not start `abort`, `static-fire`, `max-q`, or `catch`.

### Phase 3: Synchronization & Recovery

1. Wait for all sub-agents in the wave.
2. Validate receipts against the blueprint only; never inspect files, contents,
   or diffs. Any `FAIL`, `BLUEPRINT_MATCH: FAIL`, non-empty `BLOCKED`,
   non-empty `DEVIATIONS`, or missing criterion (including missing evidence)
   means the unit is not done.
3. If a receipt is `BLOCKED` or reports a blueprint gap, do not fix by
   invention and do not retry. In pipeline mode, route to a `static-fire`
   replan. Standalone BLOCKED asks the user and stops. Do not route to
   `static-fire` in standalone mode. For any other failed unit, a missing
   `Incoming RETRY_COUNT` means 0 only when `CHAIN_ID` is new. A continuation
   with a missing count halts. Do not reset the cap to 0. On a standalone
   retry cap, ask the user and stop. Do not start `abort`, `static-fire`,
   `max-q`, or `catch`. Halt before dispatching an attempt above 2. On every
   pipeline replan, pass `CHAIN_ID`, `RETRY_COUNT`, `MAP_HASH_IN`, and
   `MAP_HASH_OUT` unchanged. Do not recompute either hash. Do not mint a new
   `CHAIN_ID`. Pass
   pipeline replan.
   If that gate allows dispatch, spawn a targeted fix sub-agent with the
   same blueprint excerpt, exact error, and `Incoming RETRY_COUNT: <n>`. Set
   returned `RETRY_COUNT` to incoming + 1 and pass it forward. Reject a lower
   count than the incoming count. In standalone mode, do not invoke
   `static-fire`; stop after the final verification wave.
4. Once the Final Verification wave returns PASS, in pipeline mode hand off to
   `max-q` with the blueprint, progress ledger, detected commands, and receipts
   only; no contents or diffs. Pass `CHAIN_ID`, `RETRY_COUNT`, `MAP_HASH_IN`,
   and `MAP_HASH_OUT` verbatim. Never recompute a hash. In standalone mode, stop
   after the final verification wave. Do not stage or commit; `catch` owns
   landing.

## Forbidden

- Never add a step where the orchestrator reads implementation files or git
  diffs.
- Never allow workers to "fill in" missing design details.
- Never remove standalone mode or adaptive scaling.
