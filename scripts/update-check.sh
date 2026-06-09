#!/usr/bin/env bash
# Check whether the local Coinis skills install is up to date with origin/main.
#
# Emits a machine-readable token on the FIRST line, then human-readable detail:
#   UP_TO_DATE <version>                  — local HEAD matches remote
#   UPGRADE_AVAILABLE <local> <remote>    — remote is ahead (commit count + cmd follow)
#
# Exit codes:
#   0  up to date (or check snoozed/disabled/cached fresh)
#   1  upgrade available
#   2  error (not installed, fetch failed)
#
# Caching: a file-mtime cache avoids hammering the remote.
#   UP_TO_DATE        cached for 60 minutes
#   UPGRADE_AVAILABLE cached for 720 minutes (nag less once the user knows)
# Set COINIS_UPDATE_CHECK_DISABLED=1 to skip the check entirely (exit 0).
#
# Env overrides (testing):
#   COINIS_INSTALL_DIR   — repo root (default ~/.coinis/skills)
#   COINIS_REMOTE        — git remote name (default origin)
#   COINIS_BRANCH        — branch (default main)
#   COINIS_STATE_DIR     — cache dir (default ~/.coinis/state)

set -euo pipefail

INSTALL_DIR="${COINIS_INSTALL_DIR:-$HOME/.coinis/skills}"
REMOTE="${COINIS_REMOTE:-origin}"
BRANCH="${COINIS_BRANCH:-main}"
STATE_DIR="${COINIS_STATE_DIR:-$HOME/.coinis/state}"
CACHE_FILE="$STATE_DIR/last-update-check"

# ─── Escape hatch ────────────────────────────────────────────────────────
if [ -n "${COINIS_UPDATE_CHECK_DISABLED:-}" ]; then
  exit 0
fi

# ─── Force flag busts the cache ──────────────────────────────────────────
if [ "${1:-}" = "--force" ]; then
  rm -f "$CACHE_FILE"
fi

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
  echo "Not installed at $INSTALL_DIR — run setup first." >&2
  exit 2
fi

local_ver=$(tr -d '[:space:]' < "$INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")

# ─── Cache freshness (file mtime) ────────────────────────────────────────
# Cached payload format: "<TOKEN> <fields…>". TTL depends on the token.
if [[ -f "$CACHE_FILE" ]]; then
  cached="$(cat "$CACHE_FILE")"
  case "$cached" in
    UP_TO_DATE*)        ttl=60 ;;
    UPGRADE_AVAILABLE*) ttl=720 ;;
    *)                  ttl=0 ;;
  esac
  if [[ "$ttl" -gt 0 ]]; then
    stale="$(find "$CACHE_FILE" -mmin +"$ttl" 2>/dev/null || true)"
    if [[ -z "$stale" ]]; then
      # Cache is fresh — replay it, but only if the local version still matches
      # what we cached against (a local pull invalidates the cache).
      cached_local="$(echo "$cached" | awk '{print $2}')"
      case "$cached" in
        UP_TO_DATE*)
          if [[ "$cached_local" == "$local_ver" ]]; then
            echo "$cached"
            echo "Up to date (version $local_ver) [cached]"
            exit 0
          fi ;;
        UPGRADE_AVAILABLE*)
          if [[ "$cached_local" == "$local_ver" ]]; then
            cached_remote="$(echo "$cached" | awk '{print $3}')"
            echo "$cached"
            echo "Upgrade available (local $local_ver, remote $cached_remote) [cached]"
            echo "Run: git -C $INSTALL_DIR pull --ff-only"
            exit 1
          fi ;;
      esac
    fi
  fi
fi

# ─── Live check ──────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"

if ! git -C "$INSTALL_DIR" fetch --quiet "$REMOTE" "$BRANCH" 2>/dev/null; then
  echo "Could not fetch $REMOTE/$BRANCH — check your network." >&2
  exit 2
fi

local_sha=$(git -C "$INSTALL_DIR" rev-parse HEAD)
remote_sha=$(git -C "$INSTALL_DIR" rev-parse "$REMOTE/$BRANCH")
remote_ver=$(git -C "$INSTALL_DIR" show "$REMOTE/$BRANCH:VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")

if [[ "$local_sha" == "$remote_sha" ]]; then
  echo "UP_TO_DATE $local_ver" > "$CACHE_FILE"
  echo "UP_TO_DATE $local_ver"
  echo "Up to date (version $local_ver)"
  exit 0
fi

count_behind=$(git -C "$INSTALL_DIR" rev-list --count "HEAD..$REMOTE/$BRANCH")
echo "UPGRADE_AVAILABLE $local_ver $remote_ver" > "$CACHE_FILE"
echo "UPGRADE_AVAILABLE $local_ver $remote_ver"
echo "Behind by $count_behind commit(s) (local $local_ver, remote $remote_ver)"
echo "Run: git -C $INSTALL_DIR pull --ff-only"
exit 1
