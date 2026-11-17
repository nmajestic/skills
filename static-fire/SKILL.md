---
name: Static Fire
description: Produce an exact blueprint-grade implementation plan, gate it against five confidence criteria, assign a HIGH/MEDIUM/LOW tier, and act per policy.
---

# Static Fire

`static-fire` is the planning and confidence gate for the pipeline. Before any
execution starts, it turns the request and the current context into an exact
implementation blueprint — not a high-level summary of intent.

The blueprint is the sole implementation contract: `liftoff` executes it
verbatim and `max-q` verifies it 1:1. It must be complete enough that neither
the orchestrator nor the user ever needs to read implementation code to
understand what will change. Every design decision is closed here, before
execution begins.

**Standalone Mode:** When `static-fire` is invoked directly, produce the
blueprint and the report, then stop. Do not hand off to `liftoff`. Pipeline mode
is the only mode that hands off, and it hands off only on a `HIGH` tier.

## Blueprint-Grade Standard

A plan is blueprint-grade only when every item below is explicit. Replace
placeholders and vague phrases like "handle errors appropriately" with concrete
decisions. If a `liftoff` worker would have to choose, the blueprint is
incomplete.

### Target Files

List every file the plan touches as an exact path. Mark each as `CREATE` or
`MODIFY`. Give every unit a stable `Unit ID: U<n>` (for example, `Unit ID: U1`,
`Unit ID: U2`). Prefer one unit per file so units stay file-disjoint. Never use
wildcard paths, directory-level targets, or "files like these" phrasing.

If multiple units must touch the same file, declare their serial order
explicitly. Units in the same wave must have strictly disjoint file sets.

### Interfaces & Contracts

State every public function or method signature exactly: name, parameters,
types, defaults, and return type. State every type, interface, class, or struct
definition exactly. State every data schema exactly: fields, types,
optionality, constraints, and serialized shape. For UI work, state component
props, events, and slots; for services, state request and response shapes. Do
not introduce abstractions — modules, dependencies, layers, or patterns — that
the blueprint does not name.

### Behavior & Edge Cases

Decide behavior explicitly for null, empty, invalid, and boundary inputs, for
concurrency where it is relevant, and for every error path. Name exact error
types and codes or messages, retries, fallbacks, logging, and user-visible
behavior. State the success and happy-path behavior, the exact defaults, and the
ordering or priority rules. For every category above, state either a concrete
rule or an explicit `not applicable`; omission is not allowed. Leave zero
architectural decisions to `liftoff`.

### Per-Unit Acceptance Criteria

Every unit has a stable `Unit ID: U<n>`. Every verification item gets a stable
`Criterion ID: U<n>.<m>` (for example, `U1.1`, `U1.2`). Verification items
include file existence and shape, public signatures, types, schemas, props,
edge-case behavior, error rules, constraints, and behavioral assertions.

Declare the authoritative total in the blueprint as
`Blueprint criteria total: <N>`, counting every criterion ID exactly once.

Each criterion must name the exact command or assertion and its expected result.
A test that cannot fail is not acceptance, and naming a test file without an
assertion is not acceptance either. Map each criterion to exactly one unit; a
unit is PASS only when all of its criteria pass. For modified shared code,
include regression checks that prove existing behavior still holds.

IDs and the total are immutable after approval. No criterion may be added,
removed, or renumbered. A discovered gap requires a `static-fire` revision with
a new total, never a local invention.

### Scope & Constraints

State explicit non-goals and forbidden changes: files that must not be touched,
APIs that must not change, dependencies that must not be added, and refactors
that are out of scope.

## Evaluation Criteria

1. **Context Grounding** — All target files, schemas, APIs, and variables are
   verified in the current session, not assumed.
2. **Reversibility & Blast Radius** — Changes are read-only or easily
   reversible (e.g., a local git branch), with no destructive or external side
   effects.
3. **Dependency Chain** — State whether the units are independent, so they can
   fan out in parallel, or whether they form a serial dependency chain. Any
   serial dependency chain longer than 3 steps is a warning sign where an early
   failure invalidates downstream steps.
4. **Requirement Clarity** — Success criteria are explicit and the blueprint is
   complete: every file, signature, schema, prop, edge case, and error rule is
   decided, with zero open architectural questions.
5. **Deterministic Verification** — Per-unit automated checks exist (tests,
   linters, compilers, schema validation) so success can be proven without
   human judgment.

## Confidence Tiers & Execution Policy

| Tier   | Meaning                                                                                                                                                                                                                                                                         | Action                                                                             |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| HIGH   | All targets verified, zero architectural ambiguity — every file, interface, schema, prop, edge case, and error rule fully specified — no unverified assumptions affecting any interface, schema, edge case, or behavior — reversible, and deterministic verification available. | Execute autonomously with the blueprint as the authoritative spec.                 |
| MEDIUM | Core targets verified, but at least one interface, schema, or behavior remains open-ended.                                                                                                                                                                                      | Close every gap and re-tier before `liftoff`; do not start `liftoff` while MEDIUM. |
| LOW    | Relies on unverified assumptions, has a high or irreversible blast radius, lacks clear requirements, or cannot be deterministically verified.                                                                                                                                   | Halt execution, present the plan and assumptions, and ask targeted questions.      |

**HIGH gate:** If any interface, signature, schema, prop, edge-case behavior, or
error rule is open-ended — or a `liftoff` worker would have to make an
architectural choice — the plan cannot be `HIGH`. Close the gap and re-tier
before execution.

## Required Output Format

Emit the following, every time:

- **Unverified Assumptions:** [Bullet list or "None"]
- **Criteria Assessment:** [Brief 1-line check per criterion]
- **Implementation Blueprint** — [The full plan, containing stable
  `Unit ID: U<n>` identifiers, stable `Criterion ID: U<n>.<m>` identifiers, and
  `Blueprint criteria total: <N>`, plus the five subsections below]
  - **Target Files**
  - **Interfaces & Contracts**
  - **Behavior & Edge Cases**
  - **Per-Unit Acceptance Criteria**
  - **Scope & Constraints**
- **Detected Commands:** [test / lint / type-check / build, or `none`]
- **Confidence Tier:** [HIGH | MEDIUM | LOW]
- **Next Action:** [Proceed | Close Gaps and Re-tier | Ask User]

## Command Discovery

During evaluation, inspect the repository root for `package.json`,
`pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, or CI workflows
(`.github/workflows`) to detect the project's native test, lint, type-check,
and build commands. Record the exact commands that were discovered. Also
record `none` explicitly for each check that is not configured, then pass
them forward to `catch`. `catch` may skip only checks recorded as `none`,
never a check recorded with a command. Never assume a language-specific
runner.

## Workflow

1. Read the request and the current context.
2. Discover the repository's native commands (see Command Discovery).
3. Draft the blueprint to the Blueprint-Grade Standard and close every open
   decision in it.
4. Remove every placeholder and vague phrase, then check each of the five
   Evaluation Criteria against the blueprint itself.
5. List every unverified assumption explicitly.
6. Assign exactly one confidence tier. Assign `HIGH` only when the blueprint
   carries zero architectural ambiguity.
7. Report in the required output format, then act according to the tier's
   policy. In pipeline mode, hand the blueprint to `liftoff` as the sole spec,
   and only on `HIGH`. In standalone mode, stop after the report.
