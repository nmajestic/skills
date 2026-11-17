---
name: Static Fire
description: Evaluate any plan before executing it against five confidence criteria, assign a HIGH/MEDIUM/LOW tier, and act per policy.
---

# Static Fire

Before executing any plan, run a plan confidence evaluation: assess it against
the five criteria below, list any unverified assumptions explicitly, and assign
a final discrete confidence tier (`HIGH`, `MEDIUM`, or `LOW`). Do not use
arbitrary percentages.

## Evaluation Criteria

1. **Context Grounding** — Are all target files, schemas, APIs, and variables
   verified in the current session, or are they assumed?
2. **Reversibility & Blast Radius** — Are changes read-only or easily
   reversible (e.g., local git branch), or do they carry destructive/external
   side effects?
3. **Dependency Chain** — Is the plan 1–3 atomic steps, or a long chain where
   an early failure invalidates downstream steps?
4. **Requirement Clarity** — Are success criteria and constraints explicit, or
   are requirements ambiguous/under-specified?
5. **Deterministic Verification** — Can success be proven via automated checks
   (tests, linters, compilers, schema validation), or does it require human
   judgment?

## Confidence Tiers & Execution Policy

| Tier   | Meaning                                                                                                                              | Action                                                                                       |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| HIGH   | All targets verified in context, reversible, clear success criteria, and deterministic verification available.                       | Execute autonomously and run verification.                                                   |
| MEDIUM | Core targets verified, minor assumptions made, multi-step dependencies, and reversible.                                              | Gather missing context or dry-run/sandbox before committing changes.                         |
| LOW    | Relies on unverified assumptions, has a high/irreversible blast radius, lacks clear requirements, or cannot be deterministically verified. | Halt execution, present the plan and assumptions, and ask targeted clarifying questions. |

## Required Output Format

Emit the following, every time:

- **Unverified Assumptions:** [Bullet list or "None"]
- **Criteria Assessment:** [Brief 1-line check per criterion]
- **Acceptance Criteria:** [Explicit, testable success criteria]
- **Detected Commands:** [test / lint / type-check / build, or `none`]
- **Confidence Tier:** [HIGH | MEDIUM | LOW]
- **Next Action:** [Proceed | Gather Context / Dry-Run | Ask User]

## Command Discovery

During evaluation, inspect the repository root for `package.json`,
`pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, or CI workflows
(`.github/workflows`) to detect the project's native test, lint, type-check,
and build commands. Record the exact commands discovered (or `none` when a
check is not configured) and pass them forward to `catch`. Never assume a
language-specific runner.

## Workflow

1. Read and understand the proposed plan and the user's request.
2. Discover the repository's native commands (see Command Discovery).
3. Assess each of the five criteria against what is actually known in the
   current session — not assumed.
4. List every unverified assumption explicitly.
5. Assign exactly one confidence tier.
6. Report in the required output format, then act according to the tier's
   policy.
