---
name: Orbital Survey
description: Pre-planning reconnaissance that maps unfamiliar or multi-module repositories in parallel and persists a distilled architectural terrain map at docs/orbital-survey.md.
---

# Orbital Survey

`orbital-survey` is pre-planning reconnaissance. Before `static-fire` plans a
change, orbital-survey maps unfamiliar or multi-module repositories in
parallel and persists a distilled architectural terrain map at
`docs/orbital-survey.md`.

## Rules

- **Read-only across source code.** The only permitted write target is
  `docs/orbital-survey.md` (creating `docs/` if it does not exist).
- **Parallel scouting.** Fan out four specialized read-only scout sub-agents
  simultaneously in one batch:
  1. Control Flow & Entry Points
  2. Data Models & Schemas
  3. Shared Conventions & Helpers
  4. Tests, Build & Repo Guidelines
  For small repositories (< 20 files), scale down to 1–2 scouts.
- **Structured receipts.** Each scout returns a compact structured receipt
  (< 120 words) with `KEY_FILES`, `EXISTING_CONTRACTS`, `REUSABLE_HELPERS`,
  and `LANDMINES`.
- **Distilled map.** Synthesize the receipts into `docs/orbital-survey.md`
  (< 500 words) containing:
  - `Last Synced Commit` — a bare HEAD hash only, no timestamp, for staleness checks
  - `System Architecture & Control Flow`
  - `Canonical Data Models & Contracts`
  - `Reusable Utilities & Repo Conventions`
  - `Known Landmines & Coupling Points`
  - `Discovered Commands` — test, lint, type-check, build

## Incremental Updates

- If `docs/orbital-survey.md` exists and is valid: scout only
  new, unmapped, or changed directories (per `git log --name-only` and
  `git status --short` since `Last Synced Commit`) and patch the affected
  sections; refresh `Last Synced Commit` to the bare HEAD hash`.
- If the map is missing, invalid (missing required sections or `Last Synced Commit`), or lacks
  coverage for the target area: rescan and generate or rewrite the map.

Never rescan the entire repository when the existing map is valid, covers the
target area, and is not stale.

## Invocation

- **Automatic:** `static-fire` triggers orbital-survey first when the map is
  missing, stale, or lacks coverage for the target modules.
- **Standalone:** `"run orbital-survey"` — produce or update the map, then
  stop.
- **Handoff receipt:** After every map write or update, record the map's
  content hash in the handoff receipt: `MAP_HASH: <sha256 of
  docs/orbital-survey.md>`, so `max-q` and `catch` can mechanically verify the
  map edit.

## Guardrails

- Never modify source code; the map is the single write target.
- Never include secrets, credentials, or sensitive environment details.
- Enforce the word caps deterministically with `wc -w` before writing: a scout
  receipt over 120 words or a map over 500 words is a FAIL to regenerate, not
  a deliverable. Cap regeneration at two attempts; after two over-cap results,
  halt and escalate to the user instead of looping.
- Every map write or update receipt must include `MAP_HASH: <sha256 of docs/orbital-survey.md>`.
