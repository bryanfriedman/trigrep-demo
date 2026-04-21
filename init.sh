#!/usr/bin/env bash
#
# Initializes the Trigrep demo environment.
#
# Clones the multi-repo set into multi-repo/ for the CLI demo, and a single
# repo into no-trigrep/ and with-trigrep/ for the side-by-side agent demo.
# Builds LSTs so `mod search` has something to query against.
#
# Usage: ./init.sh [--skip-build] [--skip-index] [--clean] [--reset]
#   --skip-build          Clone only; don't run `mod build`
#   --skip-index          Skip `mod postbuild search index` (useful if you want
#                         to run it live during the demo as a setup reveal)
#   --clean               Remove cloned repos and .moderne artifacts, then exit
#   --reset               Clean and re-initialize (equivalent to --clean + init)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS_CSV="$SCRIPT_DIR/repos.csv"
MULTI_DIR="$SCRIPT_DIR/multi-repo"
NO_DIR="$SCRIPT_DIR/no-trigrep"
WITH_DIR="$SCRIPT_DIR/with-trigrep"

# Single-repo pick for the MCP agent side-by-side.
SINGLE_REPO_PATH="Netflix/eureka"
SINGLE_REPO_URL="https://github.com/Netflix/eureka"
SINGLE_REPO_BRANCH="master"

SKIP_BUILD=false
SKIP_INDEX=false
CLEAN=false
RESET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=true; shift ;;
    --skip-index) SKIP_INDEX=true; shift ;;
    --clean)      CLEAN=true; shift ;;
    --reset)      CLEAN=true; RESET=true; shift ;;
    -h|--help)
      sed -n '3,14p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ "$CLEAN" = true ]; then
  echo "==> Cleaning demo directories..."
  rm -rf "$MULTI_DIR" "$NO_DIR" "$WITH_DIR" "$SCRIPT_DIR/.moderne"
  echo "==> Clean complete."
  [ "$RESET" = false ] && exit 0
fi

if [ ! -f "$REPOS_CSV" ]; then
  echo "Error: repos.csv not found at $REPOS_CSV" >&2
  exit 1
fi

# Multi-repo clone for the CLI demo.
# `mod git sync` returns non-zero on partial success; don't let that kill the
# rest of the script — we'll surface any missing clones afterward.
echo "==> Syncing multi-repo set into multi-repo/..."
mkdir -p "$MULTI_DIR"
mod git sync csv "$MULTI_DIR" "$REPOS_CSV" --with-sources --yes || true

# Single-repo clones for the side-by-side agent demo.
clone_single() {
  local target="$1"
  echo "==> Cloning $SINGLE_REPO_PATH into $(basename "$target")/..."
  mkdir -p "$target/$(dirname "$SINGLE_REPO_PATH")"
  if [ ! -d "$target/$SINGLE_REPO_PATH" ]; then
    git clone --branch "$SINGLE_REPO_BRANCH" --single-branch \
      "$SINGLE_REPO_URL" "$target/$SINGLE_REPO_PATH"
  else
    echo "    (already exists; skipping clone)"
  fi
}
clone_single "$NO_DIR"
clone_single "$WITH_DIR"

WITH_SINGLE="$WITH_DIR/$SINGLE_REPO_PATH"
NO_SINGLE="$NO_DIR/$SINGLE_REPO_PATH"

# Drop MCP configs and launcher symlinks into each lane.
mkdir -p "$WITH_SINGLE/.claude"
cat > "$WITH_SINGLE/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "moderne": {
      "type": "stdio",
      "command": "bash",
      "args": [
        "-c",
        "if [ -x \"$HOME/.moderne/cli/bin/mod\" ]; then exec \"$HOME/.moderne/cli/bin/mod\" mcp; else exec mod mcp; fi"
      ]
    }
  }
}
EOF

cat > "$NO_SINGLE/empty-mcp.json" <<'EOF'
{
  "mcpServers": {}
}
EOF

ln -sf "$SCRIPT_DIR/start.sh" "$NO_SINGLE/start.sh"
ln -sf "$SCRIPT_DIR/start.sh" "$WITH_SINGLE/start.sh"

# Tell the agent in with-trigrep/ to prefer Trigrep over grep.
cat > "$WITH_SINGLE/CLAUDE.md" <<'EOF'
# Agent guidance for this repo

This repo has the Moderne MCP server configured. When you need to search the
codebase — for symbols, methods, classes, references, annotations, inheritance,
visibility, or return types — use the Moderne MCP tools (backed by Trigrep)
instead of grep or filesystem reads. Trigrep returns structured, typed results
from pre-built LSTs, so you can skip the read-to-confirm-type loop.

Reach for grep only when Trigrep can't express the query (free-text prose in
comments, non-Java files, etc.).
EOF

if [ "$SKIP_BUILD" = false ]; then
  echo "==> Building LSTs for multi-repo set (this may take a while)..."
  for repo in "$MULTI_DIR"/*/*; do
    [ -d "$repo" ] || continue
    echo "    building $repo"
    mod build "$repo" || echo "    (build failed for $repo; continuing)"
  done

  echo "==> Building LSTs for single-repo (with-trigrep)..."
  mod build "$WITH_SINGLE" || echo "    (build failed; Trigrep won't work until this is fixed)"
else
  echo "==> Skipping LST builds (--skip-build)"
fi

if [ "$SKIP_INDEX" = false ] && [ "$SKIP_BUILD" = false ]; then
  echo "==> Building trigram search indexes for multi-repo set..."
  mod postbuild search index "$MULTI_DIR" || echo "    (index build failed)"
  echo "==> Building trigram search indexes for single-repo (with-trigrep)..."
  mod postbuild search index "$WITH_SINGLE" || echo "    (index build failed)"
elif [ "$SKIP_INDEX" = true ]; then
  echo "==> Skipping trigram index build (--skip-index)"
  echo "    Run \`mod postbuild search index <path>\` before \`mod search\`."
fi

# Symlink the token script into each single-repo dir for convenience.
for d in "$NO_SINGLE" "$WITH_SINGLE"; do
  ln -sf "$SCRIPT_DIR/session-tokens.sh" "$d/session-tokens.sh"
done

echo ""
echo "==> Init complete."
echo "    Multi-repo CLI demo: cd $MULTI_DIR && mod search ..."
echo "    Single-repo side-by-side: see DEMOS.md"
