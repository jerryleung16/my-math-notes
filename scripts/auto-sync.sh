#!/usr/bin/env bash
set -euo pipefail

BRANCH="main"
REMOTE="origin"
DO_PUSH=0
USE_STASH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --remote)
      REMOTE="$2"
      shift 2
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    --use-stash)
      USE_STASH=1
      shift
      ;;
    *)
      echo "Unknown arg: $1"
      exit 1
      ;;
  esac
done

TS="$(date '+%Y-%m-%d %H:%M:%S')"
echo "[auto-sync] Starting at $TS"

git rev-parse --is-inside-work-tree >/dev/null

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
  echo "[auto-sync] Switching branch $CURRENT_BRANCH -> $BRANCH"
  git checkout "$BRANCH"
fi

# By default, unattended runs skip sync when there are local changes.
STASH_CREATED=0
if ! git diff --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  if [[ $USE_STASH -eq 0 ]]; then
    echo "[auto-sync] Local changes detected; skipped sync to avoid interactive file-lock prompts."
    echo "[auto-sync] Re-run with --use-stash for manual conflict-handling mode."
    exit 0
  fi

  git stash push -u -m "auto-sync temp stash $TS"
  STASH_CREATED=1
  echo "[auto-sync] Saved local changes to stash"
else
  echo "[auto-sync] No local changes to stash"
fi

echo "[auto-sync] Pulling latest from $REMOTE/$BRANCH with rebase"
git pull --rebase "$REMOTE" "$BRANCH"

if [[ $STASH_CREATED -eq 1 ]]; then
  echo "[auto-sync] Restoring stashed local changes"
  if ! git stash pop; then
    echo "[auto-sync] Stash pop had conflicts. Stash entry is kept for manual recovery."
    exit 1
  fi
fi

if [[ $DO_PUSH -eq 1 ]]; then
  echo "[auto-sync] Pushing to $REMOTE/$BRANCH"
  git push "$REMOTE" "$BRANCH"
else
  echo "[auto-sync] Skipped push (use --push to enable)"
fi

echo "[auto-sync] Done"
