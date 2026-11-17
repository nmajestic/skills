---
name: Abort
description: In pipeline mode only, contain a retry-cap failure, recover the workspace, and triage the cause. A standalone failure asks the user and does not start abort unless the user runs it.
---

# Abort

`abort` contains failures and recovers the workspace. In pipeline mode it
runs when `liftoff`, `max-q`, or `catch` hits a retry cap or an unrecoverable
blocker. In standalone mode it runs only when the user asks. It isolates the
damage, finds the root cause in parallel, persists any new landmine, and
either asks the user or, in pipeline mode only, routes the recovery.

## Phase 1: Containment & Clean Rollback

Run these steps in order. Do not run `git checkout`, `git reset`, `git stash`,
or `rm` unless that command's path list is non-empty. Never use an
exclude-only pathspec. Never `git clean`. Never `git stash pop` or
`git stash apply`. Never drop `stash^{/abort-snapshot}`.

1. Before any mutation, capture `git status --porcelain=v1 -z`,
   `git diff HEAD`, and `STASH_BEFORE` from
   `git rev-parse -q --verify stash@{0}` (empty if none).
2. If `docs/orbital-survey.md` exists, copy it aside outside the repo. If that
   copy fails, halt before rollback and still emit the Abort Report.
3. Remove `docs/orbital-survey.md` from the failed-run path list. Split the
   rest into A (paths that exist in `HEAD`, `git cat-file -e HEAD:<path>`)
   and B (paths absent from `HEAD`). Record map state as `clean`,
   `missing-tracked`, `missing-untracked`, or `staged-delete`
   (`git diff --cached --name-status -- docs/orbital-survey.md` shows `D`).
4. If A is empty, skip checkout. If A is non-empty, run
   `git checkout HEAD -- <A>`. A nonzero exit halts. Do not reset, delete, or
   drop after a halt. Never `git checkout` a path absent from `HEAD`.
5. If B is empty, skip reset and delete. If B is non-empty, run
   `git reset -q HEAD -- <B>`, then delete only those paths. Never delete the
   map. Never delete a path that was not in the failed-run create list.
6. Restore the map after A and B, in this order. Never restore or checkout
   the `HEAD` blob when an aside-copy exists.
   - If the index shows a staged deletion, run
     `git reset -q HEAD -- docs/orbital-survey.md` first. That path list is
     this one path.
   - If an aside-copy exists, restore the worktree file only from that copy,
     including when the file is missing.
   - If no aside-copy exists and the path is in `HEAD`,
     `git checkout HEAD -- docs/orbital-survey.md` is allowed for this path
     only.
   - If no aside-copy exists and the path is not in `HEAD`, halt and emit the
     Abort Report. Do not claim the map is intact.
7. Stash only when A or B is non-empty, on one line, with those paths before
   the exclude:
   `git stash push --include-untracked -m "abort-snapshot" -- <A-and-B> ':(exclude)docs/orbital-survey.md'`
   Record `STASH_AFTER`. Drop `stash@{0}` only when push exits 0, `STASH_AFTER`
   differs from `STASH_BEFORE`, and `git rev-parse stash@{0}` equals that new
   OID. If push prints `No local changes to save`, or the OID did not change,
   do not drop.
8. After rollback, `test -f docs/orbital-survey.md` when a map existed before
   rollback. Unrelated staged files and untracked files must still be present.
   `stash@{0}` is unchanged unless this run created it.

## Phase 2: Parallel Root-Cause Triage

- Ingest `docs/orbital-survey.md` when present.
- Simultaneously fan out three read-only diagnostic sub-agents:
  1. Error & Stack Trace Analyst
  2. Blueprint & Assumption Auditor
  3. Environment & Dependency Verifier
- Each returns a receipt under 100 words with `HYPOTHESIS_STATUS`,
  `ROOT_CAUSE`, and `RECOMMENDED_FIX`.

## Phase 3: Landmine Persistence & Routing

- If a non-obvious codebase landmine or hidden coupling is confirmed, append a
  concise 1-line note under `## Known Landmines & Coupling Points` in
  `docs/orbital-survey.md` (when present).
  Trim the map back under 500 words before recording `MAP_HASH`.
- Require `MAP_HASH_OUT` and `RETRY_COUNT` on every emitted artifact: the
  pipeline `static-fire` handoff and the Abort Report, including a standalone
  report. `MAP_HASH_OUT` is the sha256 of `docs/orbital-survey.md` after
  rollback and any landmine trim. If the map cannot be hashed, halt instead
  of omitting it. Do not substitute `0` for a missing `RETRY_COUNT` on a
  continuation.
- In pipeline mode only, route an auto-recoverable cause into a fresh
  `static-fire` blueprint, at most twice, copying `CHAIN_ID`, `RETRY_COUNT`,
  and `MAP_HASH_OUT` unchanged. If the failure recurs after two routes, emit
  the Abort Report and halt.
- Always emit an Abort Report under 200 words when stopping. Fields:
  `Stage Aborted`, `Workspace Status`, `Confirmed Root Cause`, `Ruled Out`,
  `Decision Needed`, `RETRY_COUNT`, and `MAP_HASH_OUT`.
- Standalone mode never invokes `static-fire`. It emits that report and stops.

## Invocation

- **Automatic:** in pipeline mode only, when `liftoff`, `max-q`, or `catch`
  hits a retry cap or an unrecoverable blocker. A standalone failure asks the
  user and does not start `abort`.
- **Standalone:** `"run abort"` — run containment, triage, and the Abort
  Report, then stop. Do not invoke `static-fire`. The report still includes
  `RETRY_COUNT` and `MAP_HASH_OUT` so a later pipeline run can continue the
  chain.

## Guardrails

- Rollback is limited to uncommitted broken changes; never delete committed
  work or the terrain map.
- Diagnostic sub-agents are read-only.
- Landmine notes stay 1 line; the Abort Report stays under 200 words.
- Reject and re-collect any diagnostic receipt over 100 words or Abort Report
  over 200 words (check with `wc -w`).
- Cap receipt and report regeneration at two attempts; after two over-cap
  results, halt and escalate to the user instead of looping.
