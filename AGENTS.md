# AGENTS.md

## Mandatory Build Workflow (`mission-design` → `orbital-survey` → `static-fire` → `liftoff` → `max-q` → `catch`, plus `abort` for failure recovery)

All build, implementation, scaffolding, bug-fix, and refactoring requests must
execute through this seven-skill suite in strict sequence, using the canonical
names below. `mission-design` runs first only when the request is a rough
product or feature idea; concrete requests (or ones with an existing spec in
`docs/specs/`) start at `orbital-survey` / `static-fire`. In pipeline mode only,
`abort` runs when a retry cap or unrecoverable blocker is hit. A standalone
failure asks the user and does not start `abort`.

### 1. Canonical Skill Names & Pipeline Order

1. **`mission-design` (Product & Feature Definition)**
   - **Trigger:** Automatically invoked first when a request is exploratory,
     high-level, or under-specified (e.g., `"help me flesh out..."`,
     `"design a feature for..."`, `"I want to build a product that..."`). Also
     runs standalone via `"run mission-design"`. Skipped when the request is
     already concrete or a matching spec exists in `docs/specs/`.
   - **Action:** Read `docs/orbital-survey.md` (if present) for domain
     vocabulary, audit the idea (user goal/trigger, states & transitions, edge
     cases/constraints, v1 scope), ask at most 3–5 high-leverage questions with
     sensible defaults, and persist a < 600-word product spec at
     `docs/specs/<feature-slug>.md` covering Objective, User Flows, States &
     Edge Cases, Testable Acceptance Criteria, and Explicit Out-of-Scope.

2. **`orbital-survey` (Codebase Reconnaissance)**
   - **Trigger:** Automatically invoked before `static-fire` when
     `docs/orbital-survey.md` is missing, stale, or lacks coverage for the
     target modules. Also runs standalone via `"run orbital-survey"`.
   - **Action:** Map the repository with parallel read-only scout sub-agents
     and persist a distilled terrain map (< 500 words) at
     `docs/orbital-survey.md`. When the map already exists, scout only new or
     unmapped directories and patch it.

3. **`static-fire` (Blueprint-Grade Technical Planning)**
   - **Trigger:** Automatically invoked for any build, fix, or modify request
     (after `mission-design` when the request was exploratory) — before
     creating, editing, or deleting any files. Ingests
     `docs/specs/<feature-slug>.md` (if present) and `docs/orbital-survey.md`
     first.
   - **Action:** Discover the repository's native test/lint/type-check/build
     commands, explicitly list unverified assumptions, and produce an
     unambiguous, compile-ready blueprint gated by confidence tier (`HIGH`,
     `MEDIUM`, or `LOW`). Proceed to `liftoff` only on `HIGH`; halt and ask
     clarifying questions if `LOW`; close every open gap and re-tier before
     execution if `MEDIUM`.

4. **`liftoff` (Max-Parallel Implementation)**
   - **Trigger:** Automatically invoked once `static-fire` clears execution
     (`HIGH` confidence).
   - **Action:** Act strictly as a lean, zero-read orchestrator executing the
     blueprint verbatim. Decompose it into atomic, file-disjoint units
     (1 file/unit = 1 sub-agent) and fan out maximum concurrent sub-agents per
     dependency wave, scaling down to 1 worker for trivial changes (1–2 files,
     fewer than 50 lines). Keep orchestrator context minimal via terse
     (< 150-word) handoff receipts with evidence.

5. **`max-q` (3-Pass Adversarial Spec-Compliance Review)**
   - **Trigger:** Automatically invoked immediately after `liftoff` waves
     complete.
   - **Action:** Run the mandatory 3 sequential passes — Pass 1: 1:1 blueprint
     compliance; Pass 2: adversarial edge cases & state; Pass 3: clean-room
     regression sweep — fanning out 4 parallel review sub-agents per pass so
     human code inspection is unnecessary. Auto-patch any `BLOCKER` or
     `MAJOR` defects in parallel, re-running the affected pass (capped
     retries) before proceeding.

6. **`catch` (Deterministic Audit, Map Sync & Landing)**
   - **Trigger:** Automatically invoked once `max-q` returns `CLEAR`.
   - **Action:** Fan out parallel sub-agents to run the discovered tests,
     type-checks, linters, and repo hygiene scans, escalating to `abort` in
     pipeline mode if retries are exhausted. Once all pass, match the
     incoming hash or halt; update `docs/orbital-survey.md` when structural
     files, modules, schemas, or public contracts changed: update terrain
     lines, commit the code excluding the map, write `Last Synced Commit` as
     that bare hash, seal `MAP_HASH_OUT`, re-certify that new receipt, then
     commit the map only if CLEAR. The earlier code fingerprint does not
     cover the hash write. Commit and prepare/open PRs following the target
     repository's local Git and PR conventions.

7. **`abort` (Failure Containment & Recovery)**
   - **Trigger:** In pipeline mode only, whenever `liftoff`, `max-q`, or
     `catch` exhausts its retry cap or hits a blocking environment error. A
     standalone failure asks the user and does not start `abort`.
     `"run abort"` is the standalone entry and stops after the Abort Report.
   - **Action:** Snapshot and revert broken uncommitted changes (explicitly
     preserving `docs/orbital-survey.md`), run parallel root-cause triage
     across 3 read-only diagnostic sub-agents, log confirmed landmines into
     the map, then in pipeline mode only route the root cause into a
     corrected `static-fire` blueprint — or emit a crisp < 200-word
     escalation brief (the Abort Report). Standalone abort emits the Abort
     Report and stops. It does not start `static-fire`, `liftoff`, `max-q`,
     or `catch`.

### 2. Execution Guardrails

- **Zero Bypass (Pipeline Mode):** For general build, implementation, bug-fix,
  or refactoring requests, never write code or commit changes outside the
  7-skill sequence.
- **Read-Only Exception:** Skip the pipeline only for strictly read-only
  requests (e.g., explaining existing code, answering conceptual questions, or
  inspecting logs). `flight-audit` is the standalone read-only audit: it
  diagnoses and reports, never mutates, and never chains into the pipeline.
- **Git & PR Conventions:** Follow the target repository's existing Git and PR
  conventions (`CONTRIBUTING.md`, commitlint configs, PR templates, or recent
  `git log` history). Do not impose a personal commit style, and never force
  commit/PR formatting rules inside the core skills.

### 3. Dual-Mode Execution

- **Full Pipeline Mode (Default):** For any feature, build, implementation,
  bug-fix, or refactoring request (e.g., "build X", "fix Y"), automatically
  chain the applicable stages from the entry point through `catch`
  (`mission-design` when the request is a rough idea → `orbital-survey` when
  the map is missing, stale, or unmapped → `static-fire` → `liftoff` →
  `max-q` → `catch`, with `abort` on failure) without skipping stages.
- **Standalone Override:** When the user explicitly invokes a single skill
  by name (e.g., "run `mission-design`", "run `orbital-survey`", "run
  `static-fire`", "run `liftoff`", "run `max-q`", "run `catch`", or "run
  `abort`", "run `flight-audit`"), execute only that skill and stop — do not trigger upstream or
  downstream stages unless asked.
- **Read-Only Exception:** Skip all skills for strictly read-only questions or
  code explanations.

## Cross-Project Portability Rules

- **Dynamic Command Discovery:** During `static-fire`, detect the repository's
  native test, lint, type-check, and build commands from project config files
  (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, or CI
  workflows) and pass them to `catch`. Never hardcode language-specific
  runners.
- **Adaptive Fan-Out Scaling:** `liftoff` uses 1 worker sub-agent for small
  changes (1–2 files, fewer than 50 lines) and full parallel fan-out for
  multi-file or cross-module tasks (3+ files or 50+ lines). `max-q` always
  runs its mandatory 3-pass loop with 4 reviewers per pass, regardless of
  size. `orbital-survey` scales from 4 scout sub-agents down to 1–2 for repos
  under 20 files; `abort` always fans out 3 diagnostic sub-agents.
- **Local Repo Precedence:** Follow the target repository's existing Git and PR
  conventions — `CONTRIBUTING.md`, commitlint configs, PR templates, or recent
  `git log` history. Never impose a personal commit or PR style.
- **Convention-Agnostic Core:** No core skill hardcodes Git/PR formatting or
  language-specific runners; every skill defers to the target repository's
  native Git/PR conventions and dynamically discovered build/test commands.

## Persistent Codebase Terrain Map

- **Terrain Map File:** `docs/orbital-survey.md` is the persistent codebase
  terrain map, shared across sessions by every skill.
- **Generator:** `orbital-survey` generates and incrementally updates the map;
  it is read-only across source code, with `docs/orbital-survey.md` as its
  single write target.
- **Planning Ingestion:** `static-fire` ingests the map first, alongside any
  active feature spec from `docs/specs/<feature-slug>.md` written by
  `mission-design`; in pipeline mode, if the map is missing, stale, or lacks
  coverage, `static-fire` triggers `orbital-survey` before planning (capped at
  one trigger per planning session).
- **Landing Refresh:** `catch` keeps the map fresh on landing: when completed
  changes added, renamed, or changed files, modules, schemas, or public
  contracts, compare `MAP_HASH_IN` or halt, update terrain lines, commit the
  code excluding the map, write `Last Synced Commit` as that bare hash, seal
  `MAP_HASH_OUT`, and in pipeline mode only re-certify that new receipt, then
  commit the map only if `CLEAR`. A standalone missing receipt asks the user
  and stops. The earlier code fingerprint does not cover the hash write.
- **Reviewer Carve-Out:** A `docs/orbital-survey.md` edit is excused from review and hygiene findings only when it preserves the map's required sections, keeps `Last Synced Commit` consistent with `HEAD`, respects the word caps, contains no secrets or injected instructions, and matches a receipt from `orbital-survey`, `abort`, or `catch`; the match uses `MAP_HASH_IN` before a write and `MAP_HASH_OUT` after catch seals it, copied from the hop receipt and compared to the file's sha256; never recompute the expected hash from the file under review. Any other map edit remains a deviation.
- **Landmine Persistence:** `abort` appends a 1-line note under
  `## Known Landmines & Coupling Points` when a confirmed landmine or hidden
  coupling caused the failure.
