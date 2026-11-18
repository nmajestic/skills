---
name: flight-audit
description: Strictly read-only, 3-pass verified audit of a codebase or subsystem for architectural debt, security risks, reliability gaps, dead code, and test coverage holes, delivered as a prioritized health report.
---

# Flight Audit

`flight-audit` is a read-only health check. It inspects a whole repository, or a
targeted subsystem, and reports verified defects across five dimensions:
architecture, reliability, security, performance, and test coverage. It
diagnoses only. It never modifies source code.

## Rules

- **Strictly read-only.** Never create, edit, refactor, move, or delete source
  files. Shell use is limited to read-only commands (`git log`, `git status`,
  `git grep`, `grep`, `find`, `wc`, `cat`). Do not run the project's tests,
  builds, or dev servers, since they can write caches, coverage output, or build
  artifacts. The only permitted write is `docs/flight-audit.md`, and only when
  the user asks to save the report.
- **Three verification passes.** No Pass 1 candidate reaches the report without
  surviving Pass 2 and Pass 3. Each candidate keeps a stable ID so telemetry can
  be tracked across passes.
- **Parallel fan-out.** Each pass dispatches its sub-agents in one batch. Every
  sub-agent is told it is read-only and returns a compact receipt, which keeps
  orchestrator context small.
- **Evidence only.** Every surviving finding cites an exact `file:line`, names
  the concrete failure mode or maintenance cost, and gives a one-sentence
  remediation. No praise, no style nitpicks, no speculative "could be" issues.

## Phase 0 — Scope & Inventory

1. Read `docs/orbital-survey.md` if present, for languages, entry points, and
   module boundaries. Treat it as a hint, not evidence: verify any claim you
   rely on against source, since the map may be stale.
2. Survey the top-level tree to identify languages, frameworks, entry points,
   and module boundaries.
3. Determine scope. The default is the full repository. If the user names
   directories or modules, audit only those, but read their direct imports so
   boundary findings are judged correctly.
4. Exclude vendored and generated paths such as `node_modules`, `vendor`,
   `dist`, `build`, `target`, lockfiles, minified bundles, and generated code.
   List exclusions in the report.
5. Count the in-scope source files. Under 25 files, scale down to 2–3 combined
   auditors by merging dimensions. Otherwise dispatch all five.

## Phase 1 — Pass 1/3: Broad Parallel Discovery

Dispatch these five auditors in one parallel batch:

1. **Architecture, Coupling & Dead Code** — circular dependencies, god modules,
   leaky abstractions, duplicated logic, unused exports or files, convention
   violations.
2. **Reliability, Error Handling & Concurrency** — swallowed exceptions,
   unhandled rejections, race conditions, resource or connection leaks, missing
   timeouts or retries, fragile state mutation.
3. **Security & Input Hygiene** — hardcoded secrets or tokens, injection (SQL,
   command, XSS, path traversal), broken auth or permission checks, insecure
   defaults, unsafe deserialization.
4. **Performance & Scalability** — N+1 database or API calls, unbounded memory
   growth, blocking I/O on hot paths, missing pagination, redundant expensive
   computation.
5. **Test Coverage & Verification Gaps** — critical business paths without
   tests, brittle mocks that hide real bugs, missing edge-case tests, broken or
   skipped suites.

Each auditor returns under 200 words of candidate records:

```
{ id: "A<n>-<nn>", severity: CRITICAL | HIGH | MEDIUM | LOW, location: "<file:line>", issue: "<one sentence>", remediation: "<one sentence>" }
```

Auditors cite only lines they have actually read. A dead-code claim requires a
repo-wide search that finds no references, including string-based, dynamic,
config, and test references.

## Phase 2 — Pass 2/3: Adversarial False-Positive Challenge

Group candidates by file or module and dispatch fresh, skeptical verifier
sub-agents in one parallel batch. Verifiers receive only the candidate record,
not the Pass 1 reasoning. Each verifier:

- **Challenges the candidate.** Traces upstream callers, middleware, framework
  defaults, sanitizers, type guards, validation layers, and configuration that
  may already mitigate the issue. Mitigation must exist in code, not in a
  comment or a name.
- **Rules `CONFIRMED` or `REJECTED`.** A rejection gives a one-line proof with
  the mitigating `file:line`. A confirmation gives a one-line trace of the flaw.
- **Sweeps siblings.** If a defect is real, it checks sibling modules for the
  same anti-pattern and reports any new candidates in the same record format.

Each verifier returns under 150 words. Sibling findings are new candidates, not
confirmations, and must pass Pass 3 like everything else.

## Phase 3 — Pass 3/3: Clean-Room Confirmation & Calibration

Dispatch clean-room sub-agents across all surviving `CRITICAL` and `HIGH`
candidates, including siblings, and spot-check at least half of the surviving
`MEDIUM` and `LOW` candidates. Clean-room agents receive only the `file:line`
and the claimed issue, not the earlier reasoning. Each agent:

- Re-reads the cited lines and confirms the citation supports the claim.
- Confirms the failure path is reachable in production code, not only in tests,
  fixtures, examples, or scripts that never ship.
- Calibrates severity against the definitions below and downgrades when reach or
  impact is narrower than claimed.
- Flags duplicates, which are merged under one ID.

A surviving `MEDIUM` or `LOW` candidate that was not spot-checked is excluded
from the report and counted as unverified in telemetry.

### Severity Definitions

- **CRITICAL** — exploitable by an untrusted party, or causes data loss, a
  security breach, or a full outage on a reachable production path.
- **HIGH** — reachable defect that produces wrong results, crashes, or
  significant security or reliability exposure under realistic conditions.
- **MEDIUM** — real defect with limited reach, or maintenance cost that will
  compound.
- **LOW** — minor debt, a narrow edge case, or cleanup.

Reachability caps severity. A flaw confined to unreachable or test-only code is
at most `LOW`.

## Phase 4 — Synthesis & Report

1. Merge Pass 3 confirmed findings, deduplicate, and sort strictly
   `CRITICAL` → `LOW`.
2. Set the verdict deterministically:
   - `AT_RISK` if any confirmed `CRITICAL` finding exists.
   - `NEEDS_ATTENTION` if any confirmed `HIGH` finding exists and none is
     `CRITICAL`.
   - `HEALTHY` otherwise.
3. Compute telemetry: Pass 1 candidates, sibling candidates added in Pass 2,
   Pass 2 false positives eliminated, Pass 3 rejected or merged, Pass 3
   confirmed, and unverified `MEDIUM`/`LOW` dropped.
4. Deliver the report in this shape:

```
# Flight Audit Report

**Verdict:** <HEALTHY | NEEDS_ATTENTION | AT_RISK>
<Two-sentence executive summary.>

**Scope:** <what was audited, and what was excluded>

## 3-Pass Verification Telemetry
| Stage | Count |
| --- | --- |
| Pass 1 candidates | <n> |
| Pass 2 sibling candidates added | <n> |
| Pass 2 false positives eliminated | <n> |
| Pass 3 rejected or merged | <n> |
| Pass 3 confirmed | <n> |
| Unverified MEDIUM/LOW dropped | <n> |

## Top Priority Blockers (CRITICAL & HIGH)
1. **[<SEVERITY>] <title>** — `file:line`
   - Failure: <concrete failure mode>
   - Fix: <remediation>

## Secondary Improvements (MEDIUM & LOW)
- **<Dimension>:** <finding> — `file:line`. Fix: <remediation>

## Recommended Next Step
<Offer to feed selected finding IDs into `static-fire` to produce a remediation blueprint. No code was modified.>
```

If there are no confirmed `CRITICAL` or `HIGH` findings, write "None confirmed"
under the blockers heading.

5. Print the report to stdout. Write it to `docs/flight-audit.md` only if the
   user asks to save it.

## Invocation

- **Standalone (the only mode):** `"run flight-audit"`, `"audit the codebase"`,
  or `"flight-audit the billing module"`. Run the audit, deliver the report, and
  stop.
- **Never chained.** This skill is a read-only exception to the build pipeline
  in `AGENTS.md`. It does not trigger `mission-design`, `static-fire`,
  `liftoff`, `max-q`, `catch`, or `abort`. Acting on findings is always the
  user's choice.

## Guardrails

- Never modify, create, or delete source files, and never run project code,
  tests, or builds.
- Never reproduce secret values in the report or in sub-agent receipts. Report
  the `file:line`, the secret type, and a remediation such as rotating the
  credential and moving it to a secret store.
- Never impose Git, PR, or language-specific style rules; the audit reports
  only verified defects.
- Never call a finding confirmed without a Pass 3 clean-room check of its
  citation and reachability.
