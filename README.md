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
