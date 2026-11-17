---
name: Catch
description: Run final deterministic audits on code changes and land them into version control with strict lowercase commit and PR standards.
---

# Catch

Execute final deterministic audits on all changes and land the work cleanly
into version control. Run verification checks via parallel sub-agents to keep
the orchestrator's context window minimal, enforce strict lowercase commit and
PR standards, and block landing if any audit fails.

**Standalone Mode:** When invoked directly without a prior `static-fire`
handoff, discover the repo's test, lint, type-check, and build commands from
`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, or CI
workflows, then stop after committing or opening the PR.

## Core Landing Principles

1. **Zero Tolerance Gatekeeper** — Unlike `max-q` (semantic code review),
   `catch` relies strictly on deterministic pass/fail signals (exit codes, test
   runners, compilers, linters, regex checks). Never commit or open a PR with a
   failing check.
2. **Parallel Audit Execution** — Fan out all independent verification checks
   simultaneously in a single batch rather than running them sequentially.
3. **Log Isolation** — Sub-agents absorb full test runner, compiler, and linter
   outputs in their isolated contexts and return only a compact status receipt
   (< 100 words).
4. **Strict Git Hygiene** — Enforce atomic commits, lowercase imperative
   formatting, and structured PR descriptions before completing the mission.

## Execution Workflow

### Phase 1: Parallel Deterministic Audit Fan-Out

Run only the commands discovered by `static-fire` (or discovered directly from
repo config files when standalone); never assume a language-specific tool. If
a check has no configured command, skip it and report `SKIPPED` rather than
failing. Spawn all applicable audit sub-agents simultaneously in a **single
parallel batch**:

1. **Sub-Agent 1 — Test Suite Runner:**
   - **Focus:** Execute unit and integration tests using the repository's
     native test command (from `static-fire`); run the full suite if fast.
   - **Output:** `PASS`, `FAIL` (exact failing test names and assertion errors
     only), or `SKIPPED` if no test suite is configured.

2. **Sub-Agent 2 — Type-Check & Build Verifier:**
   - **Focus:** Run the repository's native type-check and build commands (from
     `static-fire`) to confirm zero compilation or bundling errors.
   - **Output:** `PASS`, `FAIL` (exact file/line compiler errors only), or
     `SKIPPED` if no type-check/build command is configured.

3. **Sub-Agent 3 — Linter & Formatting Auditor:**
   - **Focus:** Run the repository's configured linter and formatter (from
     `static-fire`) across all modified files.
   - **Output:** `PASS`, `FAIL` (rule violations only), or `SKIPPED` if no
     linter/formatter is configured.

4. **Sub-Agent 4 — Repo Hygiene & Security Scan:**
   - **Focus:** Check `git status` and `git diff` for untracked temporary
     files, leftover debug logging statements, commented-out dead code, or
     accidentally staged secrets/env files.
   - **Output:** `CLEAN` or `DIRTY` with exact file paths.

### Phase 2: Audit Triage & Recovery

1. Wait for all Phase 1 sub-agents to return.
2. **If any check fails:**
   - Dispatch a single targeted fix sub-agent for the failing file(s) with the
     exact error output.
   - Re-run only the failed audit check (max 2 recovery attempts before
     escalating to the user).
3. **If all checks return `PASS` / `CLEAN` / `SKIPPED`:** Proceed immediately
   to Phase 3.

### Phase 3: Commit & PR Landing (Git Sub-Agent)

Dispatch a dedicated Git sub-agent to stage, commit, and (if requested)
prepare/open the PR following these mandatory rules:

- **Local Convention Precedence:** The lowercase
  `<label>(<optional-scope>): <description>` format and allowed labels below
  are the default standard. If the repository defines its own
  `CONTRIBUTING.md`, commitlint config, or `.github/pull_request_template.md`,
  defer to those local conventions instead.
- **Commit Format:** `<label>(<optional-scope>): <description>`
- **Casing & Grammar:** Strictly **all lowercase** (including description). Use
  imperative present tense (`add`, `fix`, `extract`, `resolve` — never `added`,
  `fixed`). Do not end with a period.
- **Allowed Labels:** `feat`, `fix`, `refactor`, `perf`, `test`, `docs`,
  `chore`, `style`.
- **Atomicity:** If changes span distinct concerns (e.g., a `feat` and a `test`
  or `docs` update), split into clean, atomic lowercase commits if appropriate,
  or use the primary overarching label.
- **PR Standard (when creating/updating a PR):**
  - **Title:** Exact same lowercase `<label>(<optional-scope>): <description>`
    format.
  - **Body:** Must contain exactly three sections:
    - `## summary`: 1–3 concise bullet points explaining what changed and why.
    - `## verification`: Exact commands executed during Phase 1 and edge cases
      verified.
    - `## risks`: Breaking changes, schema migrations, new env vars, or `none`.

### Phase 4: Mission Complete Report

Output a concise (< 100 words) final mission summary to the user confirming:

- `STATIC-FIRE` → `LIFTOFF` → `MAX-Q` → `CATCH` status (`COMPLETE`)
- Commit hash(es) and lowercase commit message(s)
- Summary of verified checks
