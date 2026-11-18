#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.config/opencode/skills"
RULES_FILE="${HOME}/.config/opencode/AGENTS.md"

mkdir -p "${SKILLS_DIR}"

for skill in mission-design orbital-survey static-fire liftoff max-q catch abort; do
  src="${REPO_DIR}/${skill}"
  dst="${SKILLS_DIR}/${skill}"
  [ -d "${src}" ] || { printf 'missing source: %s\n' "${src}" >&2; exit 1; }
  rm -rf "${dst}"
  ln -s "${src}" "${dst}"
done

[ -f "${REPO_DIR}/AGENTS.md" ] || { printf 'missing source: %s\n' "${REPO_DIR}/AGENTS.md" >&2; exit 1; }
rm -f "${RULES_FILE}"
ln -s "${REPO_DIR}/AGENTS.md" "${RULES_FILE}"

printf 'installed skills -> %s\n' "${SKILLS_DIR}"
printf 'installed rules  -> %s\n' "${RULES_FILE}"
