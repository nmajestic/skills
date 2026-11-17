# skills

A collection of six agent skills that orchestrate code changes end to end,
plus the global rules that bind them: `orbital-survey`, `static-fire`,
`liftoff`, `max-q`, `catch`, and `abort`. The pipeline is spec-driven and
zero-read.

## Core design principle

The core design principle is to front-load rigor into `static-fire` so `liftoff` runs hands-free and the implementation never needs manual reading.
`static-fire` produces an exact blueprint covering target files, signatures,
schemas, props, edge cases, error rules, and machine-verifiable acceptance
criteria. `liftoff` executes it verbatim behind a zero-read orchestrator.
`max-q` proves 1:1 compliance, and `catch` lands the result with telemetry
only.

## Pipeline

1. `orbital-survey` — pre-planning reconnaissance; maps unfamiliar or
   multi-module repositories with parallel read-only scouts and persists the
   distilled terrain map at `docs/orbital-survey.md`.
2. `static-fire` — loads the persisted terrain map (`docs/orbital-survey.md`)
   first, then blueprint-grade planning and confidence gate (`HIGH` /
   `MEDIUM` / `LOW`); any open architectural decision blocks `HIGH`.
3. `liftoff` — blind, mechanical execution via maximum parallel sub-agents;
   progress tracked only by structured `PASS`/`FAIL` receipts.
4. `max-q` — mandatory 3-pass adversarial loop: 1:1 blueprint-to-diff
   compliance, edge-case stress, and a clean-room regression sweep; no human
   code inspection.
5. `catch` — runs deterministic checks, independently re-verifies the
   blueprint's machine-verifiable criteria, then match the incoming hash or
   halt, update terrain lines, commit the code excluding the map, write
   `Last Synced Commit` as that bare hash, seal `MAP_HASH_OUT`, re-certify
   that new receipt, then commit the map only if CLEAR. The earlier code
   fingerprint does not cover the hash write. It reports telemetry only
   (spec checks, tests/builds, commit hash).
6. `abort` — failure containment and recovery: clean rollback, parallel
   root-cause triage, landmine persistence, and routing into a fresh
   `static-fire` blueprint or an Abort Report.

## Persistent terrain map

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

## Standalone override

The pipeline has two modes. In pipeline mode, each stage hands off to the
next: `orbital-survey` → `static-fire` → `liftoff` → `max-q` → `catch`, with
`abort` taking over on failure in pipeline mode only. In standalone mode, invoking any single skill
by name (including `orbital-survey` and `abort`) produces that stage's own
output and stops; no upstream or downstream stages are triggered.

## Git conventions

The skills are convention-agnostic: `catch` follows whatever Git and PR style
the target repository already uses (`CONTRIBUTING.md`, commitlint configs, PR
templates, or recent `git log` history). No skill forces a personal commit or
PR format.

To enforce a personal commit/PR style everywhere, merge the rules in
`examples/personal-git-rules.md` into your agent's global rules file (e.g.,
`~/.config/opencode/AGENTS.md`).

## Install

Run `./install.sh` to symlink all six skills and the rules into OpenCode's
global directories (`~/.config/opencode/skills` and `~/.config/opencode/AGENTS.md`).
