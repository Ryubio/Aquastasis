#!/usr/bin/env bash
# Stop hook: at the end of every Claude turn, commits any pending changes and pushes the
# current branch to origin (github.com/Ryubio/Hackaton) so the remote is always up to date.
# Never writes to `stable` -- that branch is the known-good save, moved only by save_stable.sh.

input=$(cat)
case "$input" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) retry=1 ;;
  *) retry=0 ;;
esac

cd "$(dirname "$0")/../.." || exit 0
export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never

# First failure: block the stop so Claude sees the reason and fixes it.
# Second failure in a row: just warn the user, so the hook can never loop.
fail() {
  local msg="Auto-sync failed: $1"
  msg=${msg//\\/\/}
  msg=${msg//\"/\'}
  if [ "$retry" = 0 ]; then
    printf '{"decision":"block","reason":"%s Fix it and push the changes to GitHub."}\n' "$msg"
  else
    printf '{"systemMessage":"%s"}\n' "$msg"
  fi
  exit 0
}

gitdir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
if [ -e "$gitdir/index.lock" ] || [ -d "$gitdir/rebase-merge" ] || [ -d "$gitdir/rebase-apply" ] || [ -e "$gitdir/MERGE_HEAD" ]; then
  fail "a git merge/rebase is in progress or the index is locked."
fi

branch=$(git symbolic-ref --short -q HEAD) || fail "HEAD is detached, not on a branch."
[ "$branch" = "stable" ] && fail "the stable branch is checked out; auto-sync never commits to it."

git add -A 2>/dev/null
if ! git diff --cached --quiet; then
  count=$(git diff --cached --name-only | wc -l | tr -d ' ')
  files=$(git diff --cached --name-only | head -n 5 | tr '\n' ' ')
  summary="Auto-sync: ${files% }"
  [ "$count" -gt 5 ] && summary="$summary (+$((count - 5)) more)"
  git commit -q -m "$summary" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" || fail "git commit failed."
fi

# Nothing new compared with the last known remote state: skip the network round trip.
if git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null &&
   [ "$(git rev-list --count "origin/$branch..HEAD")" -eq 0 ]; then
  exit 0
fi

git fetch -q origin 2>/dev/null || fail "could not reach origin (git fetch)."
if git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null &&
   [ "$(git rev-list --count "HEAD..origin/$branch")" -gt 0 ]; then
  if ! git pull -q --rebase origin "$branch" >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1
    fail "origin/$branch has new commits that conflict with local ones; the rebase was aborted."
  fi
fi

out=$(git push -q origin "$branch" 2>&1) || fail "git push failed: $(printf '%s' "$out" | tail -n 1)"
exit 0
