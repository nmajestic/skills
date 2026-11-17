# skills

A collection of agent skills that orchestrate code changes through a
four-stage pipeline, plus the global rules that bind them. The pipeline is
spec-driven and zero-read.

## Core design principle

The core design principle is to front-load rigor into `static-fire` so `liftoff` runs hands-free and the implementation never needs manual reading.
`static-fire` produces an exact blueprint covering target files, signatures,
schemas, props, edge cases, error rules, and machine-verifiable acceptance
criteria. `liftoff` executes it verbatim behind a zero-read orchestrator.
`max-q` proves 1:1 compliance, and `catch` lands the result with telemetry
only.

## Pipeline

1. `static-fire` — blueprint-grade planning and confidence gate (`HIGH` /
   `MEDIUM` / `LOW`); any open architectural decision blocks `HIGH`.
2. `liftoff` — blind, mechanical execution via maximum parallel sub-agents;
   progress tracked only by structured `PASS`/`FAIL` receipts.
3. `max-q` — 1:1 blueprint-to-diff compliance audit plus adversarial stress
   review; no human code inspection.
4. `catch` — runs deterministic checks, independently re-verifies the
   blueprint's machine-verifiable criteria, commits, and reports telemetry only
   (spec checks, tests/builds, commit hash).

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
next: `static-fire` → `liftoff` → `max-q` → `catch`. In standalone mode,
invoking a single skill by name produces that stage's own output and stops;
no upstream or downstream stages are triggered.

## Git conventions

The skills are convention-agnostic: `catch` follows whatever Git and PR style
the target repository already uses (`CONTRIBUTING.md`, commitlint configs, PR
templates, or recent `git log` history).

To enforce a personal commit/PR style everywhere, merge the rules in
`examples/personal-git-rules.md` into your agent's global rules file (e.g.,
`~/.config/opencode/AGENTS.md`).

## Install

Run `./install.sh` to symlink the skills and rules into OpenCode's global
directories (`~/.config/opencode/skills` and `~/.config/opencode/AGENTS.md`).
