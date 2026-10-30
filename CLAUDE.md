# CLAUDE.md

The game spec and build rules live in [README.md](README.md). This file only covers how work is saved.

## Git workflow (remote: github.com/Ryubio/Hackaton)

- `main` is live: every change (addition, removal, fix) is committed and pushed to `origin/main` right away, with a meaningful commit message. The Stop hook `.claude/hooks/auto_sync.sh` (enabled in `.claude/settings.local.json`) commits and pushes anything left over at the end of each turn.
- `stable` is the last version known to run without errors. Never commit to it directly and never force-push it. After a change has been verified in Godot (no console errors), record it with:
  `bash .claude/scripts/save_stable.sh "<what works>"`
  This tags the commit `save/<date>_<time>` and fast-forwards `origin/stable`.
- To get back a working version: `git checkout stable`, or `git checkout save/<date>_<time>` for an older one.
- Never rewrite published history (`push --force`, `reset --hard` on pushed commits, deleting `save/*` tags).
