# skills

Eight agent skills for OpenCode, plus the global rules that bind them.

Seven skills form a spec-driven, zero-read pipeline that takes a change from
idea to landed commit: `mission-design`, `orbital-survey`, `static-fire`,
`liftoff`, `max-q`, `catch`, and `abort`. The eighth, `flight-audit`, is a
standalone, strictly read-only health audit that sits outside the pipeline.

## Requirements

- OpenCode with support for global skills (`~/.config/opencode/skills`) and a
  global `AGENTS.md` rules file.
- `bash`, `ln`, and `mkdir` for `install.sh`.
- `git` in the target repository. The skills read history and status, and
  `catch` commits and prepares PRs.

## Quick start

```bash
git clone https://github.com/nmajestic/skills.git
cd skills
./install.sh
```

Then, in OpenCode, from inside the project you want to change:

- `"help me flesh out a notifications feature"` — starts the full pipeline
  from `mission-design`.
- `"fix the CSV export bug"` — starts at `orbital-survey` / `static-fire`.
- `"run flight-audit"` — produces a read-only health report and changes nothing.

All artifacts (`docs/specs/`, `docs/orbital-survey.md`, `docs/flight-audit.md`)
are written into the target project, not into this repository.

## Skills at a glance

| # | Skill | Stage | Primary output |
| - | ----- | ----- | -------------- |
| 1 | `mission-design` | Product & feature definition | `docs/specs/<feature-slug>.md` |
| 2 | `orbital-survey` | Codebase reconnaissance | `docs/orbital-survey.md` |
| 3 | `static-fire` | Blueprint-grade technical planning | Implementation blueprint (`HIGH` gate) |
| 4 | `liftoff` | Max-parallel implementation | Source changes per blueprint |
| 5 | `max-q` | 3-pass adversarial spec-compliance review | `MAX-Q PASSED` verdict + fixes |
| 6 | `catch` | Deterministic audit, map sync & landing | Commits/PRs + synced map |
| 7 | `abort` | Failure containment & recovery | Rollback + < 200-word Abort Report |
| — | `flight-audit` | Standalone read-only health audit (outside the pipeline) | 3-pass verified report (`docs/flight-audit.md` on request) |

Pipeline: `mission-design` → `orbital-survey` → `static-fire` → `liftoff` →
`max-q` → `catch`, with `abort` on failure (pipeline mode only).

## Core design principle

Front-load rigor into `static-fire` so `liftoff` runs hands-free and the
implementation never needs manual reading. `static-fire` produces an exact
blueprint covering target files, signatures, schemas, props, edge cases, error
rules, and machine-verifiable acceptance criteria. `liftoff` executes it
verbatim behind a zero-read orchestrator. `max-q` proves 1:1 compliance, and
`catch` lands the result with telemetry only.

## Pipeline

1. `mission-design` — upstream product definition; turns rough ideas into
   unambiguous, < 600-word product specs at `docs/specs/<feature-slug>.md`
   (Objective, User Flows, States & Edge Cases, Testable Acceptance Criteria,
   Explicit Out-of-Scope) via at most 3–5 high-leverage questions with
   sensible defaults. Runs only for exploratory, high-level, or
   under-specified requests.
2. `orbital-survey` — codebase reconnaissance; maps unfamiliar or
   multi-module repositories with parallel read-only scouts (4 for larger
   repositories, 1–2 for repositories under 20 files) and persists the
   distilled terrain map (< 500 words) at `docs/orbital-survey.md`. Incremental
   updates scout only changed or unmapped directories.
3. `static-fire` — blueprint-grade technical planning; ingests the active
   feature spec (`docs/specs/<feature-slug>.md`, if present) and the terrain
   map (`docs/orbital-survey.md`) first, discovers the repo's native
   test/lint/type-check/build commands, lists assumptions, and produces an
   unambiguous, compile-ready blueprint gated by confidence (`HIGH` /
   `MEDIUM` / `LOW`). Any open architectural decision blocks `HIGH`, and only
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
   blueprint's machine-verifiable criteria. It then compares `MAP_HASH_IN`
   against the map or halts. When structural files, modules, schemas, or
   public contracts changed, it updates `docs/orbital-survey.md`: it commits
   the code excluding the map, writes `Last Synced Commit` as that bare hash,
   seals `MAP_HASH_OUT`, re-certifies that new receipt, and commits the map
   only if `CLEAR`. The earlier code fingerprint does not cover the hash write.
   Commits and PRs follow the target repository's local Git conventions;
   reporting is telemetry only (spec checks, tests/builds, commit hash).
7. `abort` — failure containment & recovery; triggered when `liftoff`,
   `max-q`, or `catch` exhausts its retry cap or hits a blocking environment
   error (pipeline mode only). Snapshots/reverts broken uncommitted changes
   (explicitly preserving `docs/orbital-survey.md`), runs parallel root-cause
   triage across 3 read-only diagnostic sub-agents, logs confirmed landmines
   to the map, and routes into a corrected `static-fire` blueprint or a
   crisp < 200-word Abort Report.

## Flight audit (standalone)

`flight-audit` is a strictly read-only, 3-pass verified audit of a whole
repository or a targeted subsystem. It reports architectural debt, security
risks, reliability gaps, performance bottlenecks, dead code, and test coverage
holes. It never creates, edits, or deletes source files, and it never runs the
project's tests or builds.

- **Pass 1 — discovery.** Five auditors run in one batch (2–3 combined auditors
  for repositories under 25 files) and return candidate findings with
  severity, `file:line`, issue, and remediation.
- **Pass 2 — false-positive challenge.** Fresh verifiers trace callers,
  middleware, sanitizers, and validation for each candidate, reject anything
  already mitigated, and sweep sibling modules for the same anti-pattern.
- **Pass 3 — clean-room confirmation.** Agents that see only the citation and
  claim re-check every `CRITICAL` and `HIGH` finding (and spot-check
  `MEDIUM`/`LOW`), confirm the failure path is reachable in production code,
  and calibrate severity.

The verdict is `AT_RISK` if any confirmed `CRITICAL` finding exists,
`NEEDS_ATTENTION` if the worst confirmed finding is `HIGH`, and `HEALTHY`
otherwise. The report includes 3-pass telemetry (candidates, false positives
eliminated, findings confirmed), prioritized blockers, secondary improvements,
and a suggested next step: feeding selected findings into `static-fire`. The
report prints to the conversation; it is saved to `docs/flight-audit.md` only
if you ask. Secret values are never reproduced in the report.

`flight-audit` never chains into the pipeline. Acting on its findings is your
decision.

## Persistent `docs/` artifacts

These files live in the target project.

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
- `static-fire` loads the map first instead of broad exploration. In pipeline
  mode it triggers `orbital-survey` when the map is missing, stale, or
  unmapped, capped at one trigger per planning session.
- `catch` keeps the map current on landing (see step 6 above). In standalone
  mode, a missing `MAP_HASH_IN` makes `catch` ask you and stop; re-certify and
  the map commit are pipeline-only. It does not start `max-q` or `abort`.
- `abort` appends confirmed landmines to the map's
  `## Known Landmines & Coupling Points` section during failure recovery.

### Audit reports — `docs/flight-audit.md`

- Written only when you ask `flight-audit` to save its report. Otherwise the
  report is shown in the conversation and nothing is written.

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
- `"run flight-audit"` — strictly read-only 3-pass audit + health report, stop

**Read-only exception.** Purely read-only questions and code explanations skip
all skills. `flight-audit` is the explicit read-only audit and is never part of
the pipeline.

## Git conventions

The skills are convention-agnostic: `catch` follows whatever Git and PR style
the target repository already uses (`CONTRIBUTING.md`, commitlint configs, PR
templates, or recent `git log` history). No skill forces a personal commit or
PR format.

To enforce a personal commit/PR style everywhere, merge the rules in
`examples/personal-git-rules.md` into your agent's global rules file (e.g.,
`~/.config/opencode/AGENTS.md`).

## Install

Run `./install.sh` to symlink all eight skills and the rules into OpenCode's
global directories:

- `~/.config/opencode/skills/<skill>` → each skill directory in this repo
- `~/.config/opencode/AGENTS.md` → this repo's `AGENTS.md`

The installer is idempotent — re-run it after pulling updates.

**Heads-up:** the installer replaces anything already at those paths. An
existing `~/.config/opencode/AGENTS.md` is removed and replaced by a symlink
without a backup, so move any personal rules into `examples/` or a copy first.
Skill directories with the same names are also replaced.

### Update

```bash
cd skills
git pull
./install.sh
```

### Uninstall

```bash
rm ~/.config/opencode/skills/{mission-design,orbital-survey,static-fire,liftoff,max-q,catch,abort,flight-audit}
rm ~/.config/opencode/AGENTS.md
```

The repo is 100% self-contained: no external downloads, and no Git/PR
formatting rules are imposed on target repositories.

## Repository layout

```
.
├── AGENTS.md               # Global rules: pipeline order, guardrails, dual-mode execution
├── install.sh              # Symlinks skills and rules into ~/.config/opencode
├── README.md
├── examples/
│   └── personal-git-rules.md   # Optional personal commit/PR style
├── mission-design/SKILL.md
├── orbital-survey/SKILL.md
├── static-fire/SKILL.md
├── liftoff/SKILL.md
├── max-q/SKILL.md
├── catch/SKILL.md
├── abort/SKILL.md
└── flight-audit/SKILL.md
```

Each skill is a directory containing a `SKILL.md` with `name` and `description`
frontmatter. The `name` must be lowercase kebab-case and match the directory
name.

## Adding or changing a skill

1. Create `<skill-name>/SKILL.md` with the frontmatter above.
2. Add the directory name to the loop in `install.sh`.
3. List the skill in this README (table, pipeline or standalone sections) and,
   if it changes the workflow, in `AGENTS.md`.
4. Re-run `./install.sh` so the new skill is linked.
