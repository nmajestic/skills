---
name: Catch
description: Run final deterministic audits, land changes following the target repository's Git conventions, and report a telemetry-only summary.
---

# Catch

Catch is the final deterministic gate and landing stage. It verifies the
records and checks, lands the work, and reports telemetry only so no human
needs to inspect implementation details.

**Standalone Mode:** Without a `static-fire` handoff, discover the repo's test,
lint, type-check, and build commands, run the full Phase 1 audit, commit and
report, then stop. Mark the Spec Ledger Verifier and Blueprint Criteria Verifier
`SKIPPED` when no blueprint exists. Do not invoke max-q or any downstream stage.

## Core Landing Principles

1. **Zero Tolerance Gatekeeper** — Rely only on deterministic pass/fail
   signals (exit codes, test runners, compilers, linters, regex checks). Never
   commit with a failing check.
2. **Parallel Audit Execution** — Fan out all independent checks in a single
   batch rather than running them sequentially.
3. **Log Isolation** — Sub-agents absorb full test runner, compiler, and linter
   logs in their isolated contexts and return compact receipts.
4. **Telemetry-Only Reporting** — The final report is a compact status matrix
   covering spec checks, tests, type-check/build, lint, hygiene, and the commit
   hash. Never paste code snippets, diffs, or file contents, and
   never ask the user to review implementation details. If human attention is
   required, state only the exact failing check and error.
5. **Strict Git Hygiene** — Enforce atomic commits and clear, structured PR
   descriptions that match the target repository's conventions.

## Execution Workflow

### Phase 1: Parallel Deterministic Audit Fan-Out

Run only the commands discovered by `static-fire` or found in the repo config;
never assume a language-specific tool. **Skip gating:** `SKIPPED` is valid only
when `static-fire` recorded `none` for that check, or standalone discovery found
no command. A check recorded with a command that is skipped is `FAIL`.

Spawn all applicable audit sub-agents simultaneously in a single parallel batch:

1. **Spec Ledger Verifier:** Verify every blueprint unit has a liftoff receipt
   with the correct `UNIT: U<n>`, every criterion ID has `PASS` plus evidence,
   `BLOCKED: none`, `DEVIATIONS: none`, `SPEC_COMPLIANCE` equals the blueprint's
   `<N>/<N>`, the full-tree fingerprint matches, and max-q reported zero
   findings. Output `PASS <N>/<N>` only when all of the above hold; otherwise
   output `FAIL` naming the stale or missing item. Output `SKIPPED` only in
   standalone mode without a blueprint.
2. **Blueprint Criteria Verifier:** Independently execute every blueprint
   criterion command/assertion (file existence, signatures, schemas/props,
   grep/absence, behavioral assertions) against the working tree. Do not trust
   liftoff receipts. Output `PASS <n>/<N>` only when every criterion passes;
   otherwise output `FAIL` with the exact criterion IDs. Output `SKIPPED` only
   in standalone mode without a blueprint.
3. **Test Suite Runner:** Execute the repository's native test command. Output
   `PASS`, `FAIL` (exact failing test names and assertions only), or
   `SKIPPED`.
4. **Type-Check & Build Verifier:** Run the repository's native type-check and
   build commands. Output `PASS`, `FAIL` (exact file/line errors only), or
   `SKIPPED`.
5. **Linter & Formatting Auditor:** Run the repository's native linter and
   formatter commands on modified files. Output `PASS`, `FAIL` (rule violations
   only), or `SKIPPED`.
6. **Repo Hygiene & Security Scan:** Inspect the full working-tree manifest
   (`git diff HEAD` plus untracked non-ignored files), planned CREATE files,
   temp/debug artifacts, and secrets. Output `CLEAN`, or `DIRTY` with exact file
   paths.

### Phase 2: Audit Triage & Recovery

1. Wait for all Phase 1 sub-agents to return their receipts.
2. **If any check fails:**
   - Dispatch one targeted fix sub-agent for the failing file(s). The fix
     payload must include the relevant blueprint excerpt, the exact criterion
     IDs, the exact error output, and the verbatim rule: change only what the
     blueprint specifies, and report `BLOCKED` instead of inventing behavior.
     Fixers may not invent.
   - A `BLOCKED` receipt routes to `static-fire` replanning, never a code patch.
   - Any source-file edit invalidates the max-q certification and every Phase 1
     audit result, so restart the full Phase 1 audit batch and recompute the
     full-tree fingerprint.
   - Cap recovery at two attempts; after two, halt and escalate.
3. **Before Phase 3 (when a blueprint exists):** Invoke a read-only full max-q
   re-certification over the complete current diff and require `<N>/<N>`, zero
   findings, and a fresh fingerprint. If re-certification edits any file or
   finds issues, restart the full Phase 1 audit batch and recompute the
   fingerprint, then re-certify. A failed re-certification must halt and
   escalate; never commit an uncertified change.
4. **If all checks return `PASS` / `CLEAN` / `SKIPPED`:** Proceed to Phase 3
   after the read-only full max-q re-certification in step 3 passes, when
   applicable.

### Phase 3: Commit & PR Landing (Git Sub-Agent)

Dispatch a dedicated Git sub-agent to stage, commit, and (if requested)
prepare/open the PR using the target repository's existing conventions. Commit
only after the Phase 2 re-certification passed, when applicable:

- **Recompute Fingerprint:** Recompute the full-tree fingerprint immediately
  before commit; a mismatch with the certified fingerprint is a halt.
- **Stage Planned Files:** Stage and verify every planned CREATE file; no
  planned file may remain untracked.
- **Detect Conventions:** Check for `CONTRIBUTING.md`, commitlint configs, PR
  templates (`.github/pull_request_template.md`), or recent `git log` history
  to determine the commit and PR style the repo actually uses.
- **Match the Repo:** Write commit messages and PR titles/descriptions in that
  style. Never impose a personal format.
- **Atomic Commits:** Split distinct concerns into clean, atomic commits as the
  repo's history suggests, or use one overarching commit.
- **PR Body:** Follow the repo's PR template if present; otherwise write a
  clear summary of what changed and how it was verified.

The Git sub-agent must return a receipt with commit hash(es), commit
message(s), and files-changed count — no code output.

## Phase 4: Telemetry Report

Output telemetry only, ideally a compact table, using exactly these signals.
Pipeline status is `COMPLETE | FAILED | BLOCKED`, never hardcoded:

| Signal | Value |
| --- | --- |
| Pipeline status | `COMPLETE`, `FAILED`, or `BLOCKED` |
| Spec checks | `<N>/<N>` plus full-tree fingerprint short hash, or `SKIPPED` without a blueprint |
| Unit receipts | `<PASS> PASS / <FAIL> FAIL` |
| Max-Q verdict | `MAX-Q PASSED` or `<n> findings`, or `SKIPPED` in standalone mode |
| Tests | `PASS` / `FAIL` / `SKIPPED` |
| Type-check & build | `PASS` / `FAIL` / `SKIPPED` |
| Lint & format | `PASS` / `FAIL` / `SKIPPED` |
| Hygiene | `CLEAN` / `DIRTY` |
| Commit | `<hash> <message>` or `not committed` when halted |

Never hardcode `COMPLETE`; the pipeline status must reflect the actual outcome.
Keep the report under about 100 words. Mention any skipped or escalated check
in one line. Never include code blocks or snippets, and report errors as codes
or messages plus `file:line`. Never ask for implementation review.
