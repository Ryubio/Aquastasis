#!/usr/bin/env bash
# Records the current commit as a known-good "working save": tags it save/<date>_<time>
# and fast-forwards origin/stable to it. Run only after the game was verified to run.
# Usage: bash .claude/scripts/save_stable.sh "Phase 1 runs without errors"

set -euo pipefail
cd "$(dirname "$0")/../.."
export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never

note="${1:-Working save}"
if [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes present; commit them first." >&2
  exit 1
fi

tag="save/$(date '+%Y-%m-%d_%H-%M')"
git tag -a "$tag" -m "$note"
# Plain (non-force) push: refuses to move stable backwards or onto an unrelated history.
git push -q origin HEAD:refs/heads/stable "refs/tags/$tag"
git fetch -q origin stable
echo "Saved $(git rev-parse --short HEAD) as $tag; origin/stable updated."
