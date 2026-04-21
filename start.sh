#!/usr/bin/env bash
#
# Unified launcher for the side-by-side agent demo.
#
# From the demo root:
#   ./start.sh no|with [--yolo] [extra claude args...]
#
# From a lane's repo dir (via symlink):
#   ./start.sh [--yolo] [extra claude args...]

set -euo pipefail

INVOKED_FROM="$(cd "$(dirname "$0")" && pwd)"

case "$INVOKED_FROM" in
  */no-trigrep/*)
    LANE="no"
    REPO_DIR="$INVOKED_FROM"
    ;;
  */with-trigrep/*)
    LANE="with"
    REPO_DIR="$INVOKED_FROM"
    ;;
  *)
    LANE="${1:-}"
    shift || true
    case "$LANE" in
      no)   REPO_DIR="$INVOKED_FROM/no-trigrep/Netflix/eureka" ;;
      with) REPO_DIR="$INVOKED_FROM/with-trigrep/Netflix/eureka" ;;
      *)    echo "Usage: $0 no|with [--yolo] [extra claude args...]" >&2; exit 1 ;;
    esac
    ;;
esac

# Translate --yolo / --skip-perms shortcut.
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yolo|--skip-perms) ARGS+=("--dangerously-skip-permissions") ;;
    *)                   ARGS+=("$arg") ;;
  esac
done

cd "$REPO_DIR"

case "$LANE" in
  no)   exec claude --strict-mcp-config --mcp-config empty-mcp.json "${ARGS[@]}" ;;
  with) exec claude --strict-mcp-config --mcp-config .mcp.json      "${ARGS[@]}" ;;
esac
