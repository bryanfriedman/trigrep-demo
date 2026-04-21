# Trigrep Demo

Demo materials for showing off Trigrep (`mod search`) — Moderne's indexed code
search built from LSTs.

Two workflows, one demo:
- **Multi-repo CLI** — humans searching across a portfolio, then using
  `--last-search` to scope a recipe run.
- **Single-repo MCP** — agents using Trigrep instead of grep, eliminating the
  read-to-confirm-type loop. In testing: **16x fewer tokens** and **12x fewer
  tool calls** vs. an agent without Trigrep.

## Prerequisites

- [Moderne CLI](https://docs.moderne.io/moderne-cli/getting-started/cli-intro) (`mod`) installed and authenticated
- Git
- JDK 17+, Maven, Gradle (for LST builds)
- Python 3 (for token counting)
- Claude Code installed (for the agent side-by-side)

## Setup

```bash
./init.sh
```

This will:
1. Clone the multi-repo set (`repos.csv`) into `multi-repo/`
2. Clone the single-repo pick (`Netflix/eureka`) into both `no-trigrep/` and
   `with-trigrep/`
3. Drop a `.mcp.json` + `CLAUDE.md` into `with-trigrep/` so the agent uses
   the Moderne MCP server (backed by Trigrep)
4. Build LSTs and trigram search indexes so `mod search` works

Options:
- `--skip-build` — clone only, skip `mod build` (faster, but `mod search` won't
  work until you build manually)
- `--skip-index` — skip trigram index build (run it live during the demo)
- `--clean` — remove cloned dirs and `.moderne/` artifacts
- `--reset` — clean + re-init

## Directory layout

```
.
├── README.md
├── DEMOS.md               # step-by-step demo walkthroughs
├── QUERIES.md             # query catalog with grep contrast
├── CLAUDE.md              # project brief
├── init.sh                # setup script
├── start.sh               # unified launcher for agent side-by-side
├── session-tokens.sh      # token usage reporter
├── repos.csv              # multi-repo set for the CLI demo
├── multi-repo/            # generated — cloned + LST-built repos
├── no-trigrep/            # generated — single repo, grep-only agent lane
└── with-trigrep/          # generated — single repo, Trigrep MCP lane
```

## Running the demos

See [DEMOS.md](DEMOS.md) for the full walkthrough. For just the queries, see
[QUERIES.md](QUERIES.md).

## Side-by-side quick start

```bash
./start.sh no --yolo     # Terminal 1 — no MCP
./start.sh with --yolo   # Terminal 2 — Trigrep MCP
```

## Token counting

After each agent session, grab the session ID (`/status` in Claude Code or on
exit) and compare:

```bash
./session-tokens.sh <no-trigrep-session-id>
./session-tokens.sh <with-trigrep-session-id>
```
