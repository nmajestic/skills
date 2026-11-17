#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.config/opencode/skills"
RULES_FILE="${HOME}/.config/opencode/AGENTS.md"

mkdir -p "${SKILLS_DIR}"

for skill in static-fire liftoff max-q catch; do
  dst="${SKILLS_DIR}/${skill}"
  rm -rf "${dst}"
  ln -s "${REPO_DIR}/${skill}" "${dst}"
done

rm -f "${RULES_FILE}"
ln -s "${REPO_DIR}/AGENTS.md" "${RULES_FILE}"

printf 'installed skills -> %s\n' "${SKILLS_DIR}"
printf 'installed rules  -> %s\n' "${RULES_FILE}"
