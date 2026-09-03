#!/bin/sh
# Runs one pull/commit/push sync for a single git repo. Invoked as a
# detached background job by lua/config/git_sync.lua, so it keeps running
# even after Neovim exits -- see that file for why this lives in its own
# script rather than a sequence of calls made from Lua. Logs to $2 since a
# detached process can't call back into Neovim to report anything.
set -u

repo="$1"
log="$2"

{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') sync start: $repo ==="

  if ! git -C "$repo" pull --rebase --autostash; then
    echo "FAILED: pull"
    exit 1
  fi

  # `pull --autostash` can exit 0 while still leaving unresolved conflict
  # markers behind, if reapplying stashed local changes collided with what
  # was just pulled. Stop here rather than committing those markers.
  conflicts=$(git -C "$repo" diff --name-only --diff-filter=U)
  if [ -n "$conflicts" ]; then
    echo "FAILED: pull left unresolved conflicts, resolve manually: $conflicts"
    exit 1
  fi

  if [ -n "$(git -C "$repo" status --porcelain)" ]; then
    git -C "$repo" add -A
    git -C "$repo" commit -m "auto sync: $(date '+%Y-%m-%d %H:%M:%S')"
  fi

  if ! git -C "$repo" push; then
    echo "FAILED: push"
    exit 1
  fi

  echo "ok"
} >>"$log" 2>&1
