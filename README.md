# skills

A collection of seven agent skills that orchestrate code changes end to end,
plus the global rules that bind them: `mission-design`, `orbital-survey`,
`static-fire`, `liftoff`, `max-q`, `catch`, and `abort`. The pipeline is
spec-driven and zero-read.

## Architecture overview

| # | Skill | Stage | Primary output |
| - | ----- | ----- | -------------- |
| 1 | `mission-design` | Product & feature definition | `docs/specs/<feature-slug>.md` |
| 2 | `orbital-survey` | Codebase reconnaissance | `docs/orbital-survey.md` |
| 3 | `static-fire` | Blueprint-grade technical planning | Implementation blueprint (`HIGH` gate) |
| 4 | `liftoff` | Max-parallel implementation | Source changes per blueprint |
| 5 | `max-q` | 3-pass adversarial spec-compliance review | `MAX-Q PASSED` verdict + fixes |
| 6 | `catch` | Deterministic audit, map sync & landing | Commits/PRs + synced map |
| 7 | `abort` | Failure containment & recovery | Rollback + < 200-word Abort Report |

Pipeline: `mission-design` → `orbital-survey` → `static-fire` → `liftoff` →
`max-q` → `catch`, with `abort` on failure (pipeline mode only).

## Core design principle

The core design principle is to front-load rigor into `static-fire` so `liftoff` runs hands-free and the implementation never needs manual reading.
`static-fire` produces an exact blueprint covering target files, signatures,
schemas, props, edge cases, error rules, and machine-verifiable acceptance
criteria. `liftoff` executes it verbatim behind a zero-read orchestrator.
`max-q` proves 1:1 compliance, and `catch` lands the result with telemetry
only.

## Pipeline

1. `mission-design` — upstream product definition; turns rough ideas into
   unambiguous, < 600-word product specs at `docs/specs/<feature-slug>.md`
   (Objective, User Flows, States & Edge Cases, Testable Acceptance Criteria,
   Explicit Out-of-Scope) via at most 3–5 high-leverage questions with
   sensible defaults. Runs only for exploratory, high-level, or
   under-specified requests.
2. `orbital-survey` — codebase reconnaissance; maps unfamiliar or
   multi-module repositories with parallel read-only scouts and persists the
   distilled terrain map (< 500 words) at `docs/orbital-survey.md`.
3. `static-fire` — blueprint-grade technical planning; ingests the active
   feature spec (`docs/specs/<feature-slug>.md`, if present) and the terrain
   map (`docs/orbital-survey.md`) first, discovers the repo's native
   test/lint/type-check/build commands, lists assumptions, and produces an
   unambiguous, compile-ready blueprint gated by confidence (`HIGH` /
   `MEDIUM` / `LOW`); any open architectural decision blocks `HIGH`, and only
   `HIGH` proceeds to `liftoff`.
4. `liftoff` — max-parallel implementation; blind, mechanical execution of the
   blueprint via file-disjoint parallel sub-agents (1 worker for trivial
   1–2-file / < 50-line changes); progress tracked only by structured
   `PASS`/`FAIL` receipts.
5. `max-q` — 3-pass adversarial spec-compliance review; Pass 1: 1:1
   blueprint-to-diff compliance, Pass 2: adversarial edge cases & state,
   Pass 3: clean-room regression sweep — 4 parallel reviewers per pass; no
   human code inspection.
6. `catch` — deterministic audit, map sync & landing; runs the discovered
   tests, type-checks, linters, and hygiene scans in parallel (escalating to
   `abort` if retries are exhausted) and independently re-verifies the
   blueprint's machine-verifiable criteria, then match the incoming hash or
   halt, update `docs/orbital-survey.md` when structural files, modules,
   schemas, or public contracts changed: commit the code excluding the map,
   write `Last Synced Commit` as that bare hash, seal `MAP_HASH_OUT`,
   re-certify that new receipt, then commit the map only if CLEAR. The
   earlier code fingerprint does not cover the hash write. Commits and PRs
   follow the target repository's local Git conventions; reporting is
   telemetry only (spec checks, tests/builds, commit hash).
7. `abort` — failure containment & recovery; triggered when `liftoff`,
   `max-q`, or `catch` exhausts its retry cap or hits a blocking environment
   error (pipeline mode only). Snapshots/reverts broken uncommitted changes
   (explicitly preserving `docs/orbital-survey.md`), runs parallel root-cause
   triage across 3 read-only diagnostic sub-agents, logs confirmed landmines
   to the map, and routes into a corrected `static-fire` blueprint or a
   crisp < 200-word Abort Report.

## Persistent `docs/` artifacts

### Product specs — `docs/specs/`

- `docs/specs/<feature-slug>.md` is the product contract, written by
  `mission-design` before technical planning begins.
- `static-fire` checks `docs/specs/` for an active spec and ingests it
  alongside the terrain map; the spec's acceptance criteria feed the
  blueprint's per-unit criteria, and its out-of-scope list becomes forbidden
  changes. A missing spec never blocks planning.

### Terrain map — `docs/orbital-survey.md`

- `docs/orbital-survey.md` is the persistent codebase terrain map, shared
  across sessions.
- `orbital-survey` scouts the repository and writes/updates the map; it is
  read-only across source code, with the map as its single write target.
- `static-fire` loads the map first instead of broad exploration; in pipeline mode it triggers `orbital-survey` when the map is missing, stale, or unmapped (capped at one trigger per planning session).
- `catch` compares `MAP_HASH_IN` or asks the user and stops. In pipeline mode it updates terrain lines, commits the code excluding the map, writes `Last Synced Commit` as that bare hash, seals `MAP_HASH_OUT`, re-certifies that new receipt, then commits the map only if `CLEAR`. Re-certify and the map commit are pipeline-only. A standalone missing `MAP_HASH_IN` asks the user and stops and does not start `max-q` or `abort`. The earlier code fingerprint does not cover the hash write.
- `abort` appends confirmed landmines to the map's
  `## Known Landmines & Coupling Points` section during failure recovery.

## Zero-read guarantee

- The orchestrator never reads implementation files or diffs during
  `liftoff`.
- Reviewers mark every blueprint item PASS/FAIL with evidence; unverifiable
  items fail.
- The review set treats untracked `CREATE` files as full additions, not
  omissions from `git diff`.
- `liftoff` receipts carry per-criterion evidence, not bare `PASS` claims.
- `catch` independently executes the blueprint's machine-verifiable criteria
  rather than trusting receipts.
- Final reporting is telemetry only: no snippets and no requests to review
  implementation details.

## Usage: pipeline vs. standalone

**Full pipeline (default).** Any feature, build, or fix request automatically
chains the applicable stages from the entry point through `catch`:

- `"help me flesh out a notifications feature"` → `mission-design` →
  `orbital-survey` → `static-fire` → `liftoff` → `max-q` → `catch`
- `"fix the CSV export bug"` → `orbital-survey` (when the map is missing,
  stale, or unmapped) → `static-fire` → `liftoff` → `max-q` → `catch`
- On a retry cap or blocking failure, `abort` takes over (pipeline mode only).

**Standalone override.** Invoking a single skill by name runs only that skill
and stops — no upstream or downstream stages are triggered:

- `"run mission-design"` — spec + handoff summary only
- `"run orbital-survey"` — map write/update only
- `"run static-fire"` — blueprint + confidence report only
- `"run liftoff"` — execute a supplied blueprint, stop after verification
- `"run max-q"` — review a supplied blueprint + diff, stop after the verdict
- `"run catch"` — audit + commit code (never the map), stop
- `"run abort"` — containment + triage + Abort Report, stop

**Read-only exception.** Purely read-only questions and code explanations skip
all skills.

## Git conventions

The skills are convention-agnostic: `catch` follows whatever Git and PR style
the target repository already uses (`CONTRIBUTING.md`, commitlint configs, PR
templates, or recent `git log` history). No skill forces a personal commit or
PR format.

To enforce a personal commit/PR style everywhere, merge the rules in
`examples/personal-git-rules.md` into your agent's global rules file (e.g.,
`~/.config/opencode/AGENTS.md`).

## Install

Run `./install.sh` to symlink all seven skills and the rules into OpenCode's
global directories:

- `~/.config/opencode/skills/<skill>` → each skill directory in this repo
- `~/.config/opencode/AGENTS.md` → this repo's `AGENTS.md`

The installer is idempotent — re-run it after pulling updates. The repo is
100% self-contained: no external downloads, and no Git/PR formatting rules
are imposed on target repositories.
