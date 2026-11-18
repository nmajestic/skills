---
name: Mission Design
description: Flesh out rough product or feature ideas into unambiguous, testable product specs at docs/specs/<feature-slug>.md before technical planning begins.
---

# Mission Design

`mission-design` is the upstream product-definition stage. It turns rough,
high-level ideas into unambiguous product specifications before any technical
planning begins. It decides *what* to build and *why* — never *how*.
Architecture, target files, signatures, and implementation decisions belong to
`static-fire`, not here.

The spec is persisted at `docs/specs/<feature-slug>.md` and becomes the product
contract that `static-fire` ingests alongside `docs/orbital-survey.md` when
generating the technical blueprint.

**Standalone Mode:** When invoked directly (`"run mission-design"`), produce
the spec and the handoff summary, then stop. Do not start `orbital-survey`,
`static-fire`, or any downstream stage. Pipeline mode is the only mode that
hands off.

## Phase 1 — Context & Gap Analysis

- Read `docs/orbital-survey.md` if present. Reuse its existing domain
  vocabulary, data models, and conventions so the spec speaks the same language
  as the codebase. Never invent parallel terminology for concepts the map
  already names.
- Audit the idea across four dimensions, marking each as known, assumed, or
  missing:
  1. **User Goal / Trigger** — who wants this, what job it does, and what
     event or entry point starts the flow.
  2. **States & Transitions** — every state the feature can be in (empty,
     loading, success, error, partial) and what moves it between states.
  3. **Edge Cases / Constraints** — invalid input, boundaries, concurrency,
     permissions, performance or platform limits, and failure behavior.
  4. **v1 Scope Boundaries** — the smallest shippable slice, and what is
     deliberately deferred.

## Phase 2 — Targeted Clarification Loop

- Ask at most 3–5 concise, high-leverage questions — only gaps whose answers
  would materially change the spec. Never interrogate the user about details
  a sensible default can settle.
- Every question ships with a proposed default so the user can answer rapidly
  (e.g., "reply 'defaults' to accept all"). Batch the questions in one round.
- Record every adopted default as an explicit decision in the spec, so
  downstream stages never have to guess whether it was chosen or assumed.

## Phase 3 — Spec Generation

Write the spec to `docs/specs/<feature-slug>.md`, creating `docs/specs/` if it
does not exist. Derive `<feature-slug>` as a short kebab-case name from the
feature (e.g., `docs/specs/export-report.md`). If a spec for the same feature
already exists, update it in place rather than forking a duplicate.

The spec is < 600 words and contains exactly these sections:

- **Objective** — the user problem, the outcome, and the v1 success measure.
- **User Flows** — step-by-step happy paths from trigger to result, using the
  map's domain vocabulary.
- **States & Edge Cases** — every state, transition, and failure behavior
  decided in Phase 1/2, with concrete rules (no "handle errors appropriately").
- **Testable Acceptance Criteria** — observable, pass/fail statements a test
  or a user can verify; each maps to a flow, state, or edge case above.
- **Explicit Out-of-Scope** — deferred features and forbidden interpretations,
  so `static-fire` can treat them as non-goals.

Enforce the word cap deterministically with `wc -w` before writing: an
over-cap spec is a FAIL to regenerate, not a deliverable. Cap regeneration at
two attempts; after two over-cap results, halt and escalate to the user
instead of looping.

## Phase 4 — Handoff

- Report the saved spec path and a terse summary of the key decisions,
  including any defaults the user accepted.
- **Pipeline mode:** hand off to `orbital-survey` / `static-fire` with the spec
  path, so planning ingests the spec alongside the terrain map.
- **Standalone mode:** offer the transition ("ready to continue with
  `orbital-survey` / `static-fire`?") and stop. Do not start it unasked.

## Invocation

- **Automatic:** triggered when a request is high-level or exploratory —
  e.g., `"help me flesh out..."`, `"design a feature for..."`, `"I want to
  build a product that..."` — before `orbital-survey` and `static-fire`.
- **Standalone:** `"run mission-design"` — produce the spec and summary, then
  stop.
- **Skip:** when the request is already concrete, or a matching spec exists in
  `docs/specs/`, proceed directly to planning; do not re-run the clarification
  loop for decisions the spec already records.

## Guardrails

- Product definition only: no architecture, file paths, signatures, schemas,
  or implementation choices in the spec — those are `static-fire`'s job.
- The only permitted write target is `docs/specs/<feature-slug>.md` (creating
  `docs/specs/` if needed); everything else is read-only.
- Never include secrets, credentials, or sensitive environment details.
- Never impose Git or PR formatting rules; the suite stays convention-agnostic
  and follows the target repository's existing conventions.
