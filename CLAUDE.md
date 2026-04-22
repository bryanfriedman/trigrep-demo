# Trigrep demo project

## Goal

Build and test demo materials for two presentations about Trigrep (`mod search`):

1. **Code Remix Weekly (immediate priority):** ~20-30 min demo within an hour show. Focused on Trigrep specifically. Audience has already seen semantic search recipes on the Moderne Platform in a previous episode, so this is about what Trigrep adds.
2. **Code Remix Summit (May, 40-45 min talk):** Broader scope covering semantic search recipes + Trigrep CLI + Trigrep MCP agent workflow. The CRW demo is a subset/proving ground for this.

## Trigrep basics

Trigrep is Moderne's indexed code search. It runs against pre-built trigram indexes derived from LSTs (not raw source), so it's fast and it understands code structure. Access it via `mod search` on the CLI or through MCP for agents.

Supported semantic filters: `extends:`, `implements:`, `visibility:`, `type:method`, `type:symbol`, `throws:`, `returns:`.

NOT a valid filter: `type:annotation`.

Query syntax is intentionally similar to Sourcegraph/Zoekt (literal, regex, symbol search), with the semantic filters as the LST-powered additions those tools can't do.

## Two use cases — keep these separate

**Multi-repo CLI** (`mod search` across a working set): Human/portfolio workflow. Search across many repos. `--last-search` narrows subsequent recipe runs to only the repos that matched. Value = portfolio-scale search + bridge from fast search to precise recipe execution.

**Single-repo MCP** (agent uses Trigrep instead of grep): Agent workflow. Agent calls Trigrep through MCP while working in one repo. Value = eliminates the read loop. The token savings isn't in the search call — it's in the file reads the agent never has to make.

These are different workflows with different value props. Never conflate them in the narrative.

## Constraints

- All repos must be publicly accessible (Moderne public instance uses open source repos)
- The Trigrep UI on the platform may or may not be available. Don't depend on it.
- Prethink is explicitly out of scope for these demos.
- The single-repo for the MCP demo must be Gradle-based (Maven repos hit a `modmaven-metadata` bug in `mod mcp` on CLI 4.1.x — see filed issue). Gradle repos use `GradleBuildStep2` which works.

## Reference materials

- Prethink demo repo at ~/Documents/Demos/prethink-demo — structural reference for side-by-side format.
- Trigrep demo clip from Gartner MQ at ~/Documents/Demos/tech-debt-mq/trigrep-demo — reference for talking points.
- Token counting script at ~/Documents/Demos/prethink-demo/session-tokens.sh (copied into this repo).

---

## Current state (as of 2026-04-21)

### Repo selections (done)

**Multi-repo set** (CLI demo): 4 petclinic variants + Netflix eureka. See `repos.csv`. Dropped `spring-framework-petclinic` (2026-04-21) — its JSPs hit an NPE in the XML parser that aborted the resource build step, leaving the trigram index empty.

**Single repo** (MCP agent demo): `Netflix/eureka` (Gradle, ~409 Java files, pre-built LSTs on Moderne platform). Chose this because:
- Gradle-based — bypasses the `modmaven-metadata` bug in `mod mcp`
- Pre-built LSTs download from Moderne in seconds (no local build issues)
- Rich enough domain (`InstanceInfo`, `EurekaClient`, `Application`, lease mgmt)
- Tested side-by-side: **16x fewer tokens** (270K vs 4.4M), **12x fewer tool calls** (7 vs 84)

### Query testing (done)

See [QUERIES.md](QUERIES.md) for the full catalog. Key findings:
- `extends:` is NOT transitive (same as grep for direct subclasses)
- The real differentiators are `visibility:`, `type:method`, `returns:`, `throws:` — grep cannot express these
- `--last-search` bridge to `FindAnnotations` recipe works and is a strong demo closer

### Agent side-by-side (done)

See [DEMOS.md](DEMOS.md) for the full walkthrough. Setup:
- `./start.sh no --yolo` / `./start.sh with --yolo` from the demo root
- Prompt: "If I modify the InstanceInfo class, what other classes and services would be affected?"
- Without Trigrep: 84 tool calls, spawns a subagent, 4.4M tokens
- With Trigrep: 7 tool calls, no subagent, 271K tokens

### Known issues

- `mod mcp` on Maven repos crashes on `modmaven-metadata` (CLI 4.1.x) — filed to engineering
- `extends:` filter is text-match only, not transitive — use `visibility:` / `returns:` / `throws:` for the "grep can't do this" story instead
- MCP tools register progressively (~15s after connect) — don't prompt immediately