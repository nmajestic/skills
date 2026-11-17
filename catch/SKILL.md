---
name: Catch
description: Run final deterministic audits, land changes following the target repository's Git conventions, and report a telemetry-only summary.
---

# Catch

Catch is the final deterministic gate and landing stage. It verifies the
records and checks, lands the work, and reports telemetry only so no human
needs to inspect implementation details.

**Standalone Mode:** Without a `static-fire` handoff, discover the repo's test,
lint, type-check, and build commands, run the full Phase 1 audit, commit the
code excluding `docs/orbital-survey.md`, and report, then stop. Do not commit
the map. Mark the Spec Ledger Verifier and Blueprint Criteria Verifier
`SKIPPED` when no blueprint exists. Standalone catch never invokes static-fire or max-q. On BLOCKED, ask the user and stop. Cross-skill calls are pipeline-only.

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
   paths. A map edit is not DIRTY only when the file sha256 matches
   `MAP_HASH_IN` before a write, or `MAP_HASH_OUT` after catch seals it.
   A missing receipt is a mismatch. Never recompute the expected hash from the
   file under review. Any other map edit is DIRTY.

### Phase 2: Audit Triage & Recovery

1. Wait for all Phase 1 sub-agents to return their receipts.
2. **If any check fails:**
   - Dispatch one targeted fix sub-agent for the failing file(s). The fix
     payload must include the relevant blueprint excerpt, the exact criterion
     IDs, the exact error output, and the verbatim rule: change only what the
     blueprint specifies, and report `BLOCKED` instead of inventing behavior.
     Fixers may not invent.
   - A `BLOCKED` receipt never becomes a code patch. In pipeline mode, route it
     to `static-fire` replanning, passing `CHAIN_ID`, `RETRY_COUNT`, `MAP_HASH_IN`, and `MAP_HASH_OUT` unchanged. Do not mint a new `CHAIN_ID`. A continuation with a missing count halts. Standalone catch never invokes static-fire or max-q. On BLOCKED, ask the user and stop. Cross-skill calls are pipeline-only.
   - Any source-file edit invalidates the max-q certification and every Phase 1
     audit result, so restart the full Phase 1 audit batch and recompute the
     full-tree fingerprint.
   - Cap recovery at two attempts; after two, halt and escalate to the user.
3. **Before Map Landing (when a blueprint exists):** In pipeline mode only,
   invoke a read-only full max-q re-certification over the complete current
   diff and require `<N>/<N>`, zero findings, and a fresh fingerprint. Do not
   write the map in this step. This re-certification does not cover the later
   hash write. If re-certification finds issues, route them to max-q
   remediation or a `static-fire` replan, passing `CHAIN_ID`, `RETRY_COUNT`,
   `MAP_HASH_IN`, and `MAP_HASH_OUT` unchanged. Do not mint a new `CHAIN_ID`.
   Each route is capped at two attempts — do not
   re-certify on unchanged findings, and never replan a third time. If an edit
   occurs, restart the full Phase 1 audit batch and recompute the fingerprint.
   Cap re-certification attempts at two; after two failed re-certifications,
   halt and escalate to the user. Never commit an uncertified code change.
   Standalone catch never invokes static-fire or max-q. On BLOCKED, ask the user and stop. Cross-skill calls are pipeline-only.
4. **If all checks return `PASS` / `CLEAN` / `SKIPPED`:** Proceed to Map Landing
   and Phase 3. In pipeline mode, proceed only after the step 3 re-certification
   passes, when a blueprint exists.

### Map Landing

When `docs/orbital-survey.md` exists and the landed changes added, renamed, or
changed files, modules, schemas, or public contracts, land the map in this
order. Step 6 and any `static-fire` call are pipeline-only, per step 8.
Standalone catch does not run step 6 and does not commit the map.

1. Resolve `MAP_HASH_IN` from the in-session receipt, or, when
   `git diff --quiet <commit> -- docs/orbital-survey.md`, as the sha256 of the
   committed blob bytes (`git show <commit>:docs/orbital-survey.md` piped to
   `sha256sum`). Do not use `git rev-parse` output as that hash. A dirty map
   with no in-session receipt asks the user and stops. Do not start `abort`,
   `static-fire`, or `max-q`. A missing map skips map landing. Do not hash a
   dirty file and call that a receipt.
2. Before any write, compare `MAP_HASH_IN` to `sha256` of the current file.
   On mismatch, ask the user and stop. Do not start another skill. Copy the
   map aside on match, then update
   terrain lines only.
3. Commit the code excluding `docs/orbital-survey.md`.
4. Write `Last Synced Commit` as that bare code-commit hash.
5. Seal `MAP_HASH_OUT` as the sha256 of the written bytes. This is a new
   receipt. The next hop copies this field. Reviewers must not invent it by
   hashing the file themselves.
6. In pipeline mode only, rerun read-only max-q on the map-only delta with
   `MAP_HASH_OUT`. Commit the map only if that re-cert returns `CLEAR` and
   `sha256(file)` equals `MAP_HASH_OUT`. Otherwise restore the pre-write map
   from the aside-copy and do not commit the map.
7. The earlier code fingerprint does not cover the hash write.
8. Standalone catch never invokes `static-fire` or `max-q`. Ask the user and
   stop only when `MAP_HASH_IN` cannot be resolved: a dirty map with no
   in-session receipt, or the `Last Synced Commit` blob is unavailable. A
   worktree file that matches the committed blob is not a missing receipt.
   Do not commit the map in standalone.

### Phase 3: Commit & PR Landing (Git Sub-Agent)

Dispatch a dedicated Git sub-agent to stage, commit, and (if requested)
prepare/open the PR using the target repository's existing conventions. In
pipeline mode, commit code only after the Phase 2 re-certification passed, when
applicable. Follow Map Landing for the map:

- **Recompute Fingerprint:** Recompute the code fingerprint immediately before
  the code commit, excluding `docs/orbital-survey.md`. A mismatch on that code
  set is a halt. The earlier code fingerprint does not cover the hash write, so
  do not apply that fingerprint gate to the map commit.
- **Stage Planned Files:** Stage and verify every planned CREATE file except
  `docs/orbital-survey.md`. No other planned file may remain untracked. The map
  stays out of the code commit and is committed only under Map Landing step 6.
- **Detect Conventions:** Check for `CONTRIBUTING.md`, commitlint configs, PR
  templates (`.github/pull_request_template.md`), or recent `git log` history
  to determine the commit and PR style the repo actually uses.
- **Match the Repo:** Write commit messages and PR titles/descriptions in that
  style. Never impose a personal format.
- **Atomic Commits:** Split distinct concerns into clean, atomic commits as the
  repo's history suggests, or use one overarching commit.
- **Map Landing:** Follow the Map Landing order. Pass `MAP_HASH_IN` on the
  pre-write re-cert and `MAP_HASH_OUT` on the map-only re-cert. Pass the same
  handoff object on every pipeline replan. Standalone does not call another
  skill.
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
