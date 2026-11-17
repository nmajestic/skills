# AGENTS.md

## Mandatory Build Workflow (`orbital-survey` → `static-fire` → `liftoff` → `max-q` → `catch`, plus `abort` for failure recovery)

All build, implementation, scaffolding, bug-fix, and refactoring requests must
execute through this six-skill suite in strict sequence, using the canonical
names below. In pipeline mode only, `abort` runs when a retry cap or
unrecoverable blocker is hit. A standalone failure asks the user and does
not start `abort`.

### 1. Canonical Skill Names & Pipeline Order

0. **`orbital-survey` (Pre-Planning Reconnaissance)**
   - **Trigger:** Automatically invoked before `static-fire` when
     `docs/orbital-survey.md` is missing, stale, or lacks coverage for the
     target modules. Also runs standalone via `"run orbital-survey"`.
   - **Action:** Map the repository with parallel read-only scout sub-agents
     and persist a distilled terrain map (< 500 words) at
     `docs/orbital-survey.md`. When the map already exists, scout only new or
     unmapped directories and patch it.

1. **`static-fire` (Planning & Confidence Gate)**
   - **Trigger:** Automatically invoked first whenever asked to build, fix, or
     modify code — before creating, editing, or deleting any files. Loads
     `docs/orbital-survey.md` first.
   - **Action:** Gather context, explicitly list unverified assumptions, and
     evaluate the plan (`HIGH`, `MEDIUM`, or `LOW` confidence tier). Halt and
     ask clarifying questions if `LOW`; close every open gap before execution
     if `MEDIUM`.

2. **`liftoff` (Max-Parallel Implementation)**
   - **Trigger:** Automatically invoked once `static-fire` clears execution
     (`HIGH` confidence).
   - **Action:** Act strictly as a lean orchestrator. Decompose the blueprint
     into atomic, file-disjoint units (1 file/unit = 1 sub-agent) and fan out
     maximum concurrent sub-agents per dependency wave. Keep orchestrator
     context minimal via terse (< 150-word) handoff receipts with evidence.

3. **`max-q` (3-Pass Adversarial Parallel Review)**
   - **Trigger:** Automatically invoked immediately after `liftoff` waves
     complete.
   - **Action:** Run the mandatory 3-pass review loop (structural/spec
     compliance, adversarial edge cases, clean-room regression sweep), fanning
     out 4 review sub-agents per pass. Auto-patch any `BLOCKER` or `MAJOR`
     defects in parallel, re-running the affected pass (capped retries) before
     proceeding.

4. **`catch` (Deterministic Audit & Landing)**
   - **Trigger:** Automatically invoked once `max-q` returns `CLEAR`.
   - **Action:** Fan out parallel sub-agents to run tests, type-checks,
     linters, and repo hygiene scans. Once all pass, match the incoming hash
     or halt, update terrain lines, commit the code excluding the map, write
     `Last Synced Commit` as that bare hash, seal `MAP_HASH_OUT`, re-certify
     that new receipt, then commit the map only if CLEAR. The earlier code
     fingerprint does not cover the hash write. Prepare/open PRs if
     requested, following the target repository's existing Git and PR
     conventions.

5. **`abort` (Failure Containment & Recovery)**
   - **Trigger:** In pipeline mode only, when `liftoff`, `max-q`, or `catch`
     hits a retry cap or an unrecoverable blocker. A standalone failure asks
     the user and does not start `abort`. `"run abort"` is the standalone
     entry and stops after the Abort Report.
   - **Action:** Capture the failing diff and errors, roll back uncommitted
     broken changes (preserving `docs/orbital-survey.md`), run 3 parallel
     read-only diagnostic sub-agents, persist confirmed landmines into the
     map, then in pipeline mode only route the root cause into a fresh
     `static-fire` blueprint. Standalone abort emits the Abort Report and
     stops. It does not start `static-fire`, `liftoff`, `max-q`, or `catch`.

### 2. Execution Guardrails

- **Zero Bypass (Pipeline Mode):** For general build, implementation, bug-fix,
  or refactoring requests, never write code or commit changes outside the
  6-skill sequence.
- **Read-Only Exception:** Skip the pipeline only for strictly read-only
  requests (e.g., explaining existing code, answering conceptual questions, or
  inspecting logs).
- **Git & PR Conventions:** Follow the target repository's existing Git and PR
  conventions (`CONTRIBUTING.md`, commitlint configs, PR templates, or recent
  `git log` history). Do not impose a personal commit style, and never force
  commit/PR formatting rules inside the core skills.

### 3. Dual-Mode Execution

- **Default Pipeline Mode:** For any general build, implementation, bug-fix, or
  refactoring request (e.g., "build X", "fix Y"), automatically execute the
  full suite (`orbital-survey` when the map is missing, stale, or unmapped →
  `static-fire` → `liftoff` → `max-q` → `catch`, with `abort` on failure)
  without skipping stages.
- **Direct Standalone Override:** If the user explicitly invokes a single skill
  by name (e.g., "run `static-fire`", "use `liftoff` on this spec", "run
  `max-q` on my diff", "run `catch`", "run `orbital-survey`", or "run
  `abort`"), execute only that requested skill and halt upon completion — do
  not trigger upstream or downstream stages unless asked.
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

## Persistent Codebase Terrain Map

- **Terrain Map File:** `docs/orbital-survey.md` is the persistent codebase
  terrain map, shared across sessions by every skill.
- **Generator:** `orbital-survey` generates and incrementally updates the map;
  it is read-only across source code, with `docs/orbital-survey.md` as its
  single write target.
- **Planning Ingestion:** `static-fire` ingests the map first; in pipeline
  mode, if the map is missing, stale, or lacks coverage, `static-fire` triggers
  `orbital-survey` before planning (capped at one trigger per planning
  session).
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
