# AGENTS.md

## Mandatory Build Workflow (`static-fire` → `liftoff` → `max-q` → `catch`)

All build, implementation, scaffolding, bug-fix, and refactoring requests must
execute through these exact four skills in strict sequence, using the
canonical names below.

### 1. Canonical Skill Names & Pipeline Order

1. **`static-fire` (Planning & Confidence Gate)**
   - **Trigger:** Automatically invoked first whenever asked to build, fix, or modify code—before creating, editing, or deleting any files.
   - **Action:** Gather context, explicitly list unverified assumptions, and evaluate the plan (`HIGH`, `MEDIUM`, or `LOW` confidence tier). Halt and ask clarifying questions if `LOW`; gather missing context if `MEDIUM`.

2. **`liftoff` (Max-Parallel Implementation)**
   - **Trigger:** Automatically invoked once `static-fire` clears execution (`HIGH` confidence).
   - **Action:** Act strictly as a lean orchestrator. Decompose the plan into atomic, file-disjoint units (1 file/unit = 1 sub-agent) and fan out maximum concurrent sub-agents per dependency wave. Keep orchestrator context minimal via terse (< 150-word) handoff receipts.

3. **`max-q` (Adversarial Parallel Review)**
   - **Trigger:** Automatically invoked immediately after `liftoff` waves complete.
   - **Action:** Fan out parallel review sub-agents across the `git diff` to stress-test correctness/edge cases, cross-file contracts, acceptance criteria, and security/performance. Auto-patch any `BLOCKER` or `MAJOR` defects in parallel before proceeding.

4. **`catch` (Deterministic Audit & Landing)**
   - **Trigger:** Automatically invoked once `max-q` returns `CLEAR`.
   - **Action:** Fan out parallel sub-agents to run tests, type-checks, linters, and repo hygiene scans. Once all pass, stage and commit changes (and prepare/open PRs if requested) following the target repository's existing Git and PR conventions.

### 2. Execution Guardrails

- **Zero Bypass (Pipeline Mode):** For general build, implementation, bug-fix, or refactoring requests, never write code or commit changes outside the 4-stage sequence.
- **Read-Only Exception:** Skip the pipeline only for strictly read-only requests (e.g., explaining existing code, answering conceptual questions, or inspecting logs).
- **Git & PR Conventions:** Follow the target repository's existing Git and PR conventions (`CONTRIBUTING.md`, commitlint configs, PR templates, or recent `git log` history). Do not impose a personal commit style.

### 3. Dual-Mode Execution

- **Default Pipeline Mode:** For any general build, implementation, bug-fix, or
  refactoring request (e.g., "build X", "fix Y"), automatically execute the
  full four-stage sequence (`static-fire` → `liftoff` → `max-q` → `catch`)
  without skipping stages.
- **Direct Standalone Override:** If the user explicitly invokes a single skill
  by name (e.g., "run `static-fire`", "use `liftoff` on this spec", "run
  `max-q` on my diff", or "run `catch`"), execute only that requested skill
  and halt upon completion — do not trigger upstream or downstream stages
  unless asked.
- **Read-Only Exception:** Skip all skills for strictly read-only questions or
  code explanations.

## Cross-Project Portability Rules

- **Dynamic Command Discovery:** During `static-fire`, detect the repository's
  native test, lint, type-check, and build commands from project config files
  (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, or CI
  workflows) and pass them to `catch`. Never hardcode language-specific
  runners.
- **Adaptive Fan-Out Scaling:** For small changes (1–2 files and fewer than 50
  lines), use 1 worker sub-agent in `liftoff` and 1 combined reviewer in
  `max-q`. Engage full parallel fan-out for multi-file or cross-module tasks
  (3+ files or 50+ lines).
- **Local Repo Precedence:** Follow the target repository's existing Git and PR
  conventions — `CONTRIBUTING.md`, commitlint configs, PR templates, or recent
  `git log` history. Never impose a personal commit or PR style.
