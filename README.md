# skills

A collection of agent skills that orchestrate code changes through a
four-stage pipeline, plus the global rules that bind them.

## Pipeline

1. `static-fire` — plan confidence gate (`HIGH` / `MEDIUM` / `LOW`).
2. `liftoff` — maximum parallel sub-agent implementation.
3. `max-q` — adversarial parallel review.
4. `catch` — deterministic audit and landing.

## Standalone override

Invoke any single skill by name to run only that stage; upstream and
downstream stages are not triggered.

## Commit convention

Commits and PR titles use `<label>(<optional-scope>): <description>` —
all lowercase, imperative present tense, no trailing period. Allowed labels:
`feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `style`.

## Install

Run `./install.sh` to symlink the skills and rules into OpenCode's global
directories (`~/.config/opencode/skills` and `~/.config/opencode/AGENTS.md`).
