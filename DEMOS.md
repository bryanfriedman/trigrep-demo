# Trigrep Demos

Two demos, one hour show. Framing (2 min) → Multi-repo CLI (10-12 min) →
Single-repo MCP side-by-side (10-12 min) → Wrap-up (2 min).

## Prerequisites

Run `./init.sh` once. This clones the multi-repo set, clones the single-repo
twice (once for each side-by-side lane), and builds LSTs. See [README.md](README.md)
for options.

```bash
./init.sh
```

Quick reference of queries for each demo: [QUERIES.md](QUERIES.md).

---

## 1. Framing (2 min)

> Last episode I showed semantic search recipes running on the Moderne Platform.
> Today I want to pull on a different thread of the same infrastructure: Trigrep.
> Same LSTs underneath, but exposed through a CLI and an MCP server — built for
> speed, not depth.

Call out: "Trigrep is a trigram index built from LSTs. Fast like grep. Structural
like a recipe. And it shows up in two places: the CLI for humans searching
across a portfolio, and MCP for agents working in a single repo."

---

## 2. Multi-repo CLI demo (10-12 min)

_Trigrep across a working set of repos. Humans searching portfolios._

### Setup

```bash
cd multi-repo
ls          # show the Spring ecosystem sampler: 5 petclinic variants + Netflix eureka
```

### Step 1 — Familiar syntax (90 sec)

Open with queries the audience already knows:

```bash
mod search . '"RequestMapping"'               # literal (Sourcegraph default)
mod search . '/find\w+By\w+/'                 # regex
mod search . '"ClinicService"' type:symbol    # symbol
mod search . --syntax=zoekt RequestMapping    # same literal, Zoekt-style
```

Narrate: "Sourcegraph is the default — literals in quotes, regex in slashes.
If your muscle memory is Zoekt, `--syntax=zoekt` flips it. Same index
underneath, different surface language."

Quick reference if anyone asks:

| Goal | Sourcegraph | Zoekt |
|---|---|---|
| Literal match | `"RequestMapping"` | `RequestMapping` (regex) |
| Regex | `/findBy\w+/` | `findBy\w+` |
| Symbol lookup | `"Foo" type:symbol` | `sym:Foo` |
| NOT / exclude | `-file:test` | `-f:test` |
| Boolean AND | `foo AND bar` | `foo bar` |

Semantic filters (`extends:`, `visibility:`, `returns:`, etc.) work the same
in both modes — those are LST-backed, not dialect-specific.

More Tier 1 examples to riff on (boolean composition, file filters, regex
alternation) in [QUERIES.md](QUERIES.md#tier-1--familiar-syntax-warm-up).

### Step 2 — Semantic filters (5 min)

Layer in the filters only Trigrep has:

```bash
# Disambiguation
mod search . '"StringUtils"' type:symbol

# API surface — grep can't filter by visibility or return type
mod search . visibility:public type:method returns:ResponseEntity

# Exception surface (pick one)
mod search . throws:IOException type:method
```

Narrate the payoff: "These are queries grep literally cannot express. Visibility,
return types, throws clauses — these exist in the LST, not in raw text."

### Step 3 — Contrast with grep (90 sec)

Pick one — the `StringUtils` one lands best:

```bash
grep -rn "StringUtils" . | wc -l
```

Hundreds of lines. Then:

```bash
mod search . '"StringUtils"' type:symbol
```

Handful of declarations. "Same question, different answer shape, because the
index knows what a class is."

### Step 4 — Bridge to a recipe run (2-3 min)

The climax — fast search narrowing the working set, then a deeper search
recipe doing precise work on only the matched repos:

```bash
mod search . '"RestController"' type:symbol

mod run . --last-search --recipe=org.openrewrite.java.search.FindAnnotations \
  -PannotationPattern='@org.springframework.web.bind.annotation.RestController'
```

Narrate: "The literal search is fast but approximate — it matches any token
reading `RestController`, including imports and comments. The
`FindAnnotations` recipe is precise — it only reports actual `@RestController`
annotations. `--last-search` scopes the precise pass to only the repos that
matched the cheap one." Call attention to the "Produced results for N
repositories" line — N is smaller than the total working set.

---

## 3. Single-repo MCP side-by-side (10-12 min)

_Agent with Trigrep MCP vs. agent with grep. Same repo, same task. Value is
in the file reads the agent never has to make._

### Setup

The single-repo is `Netflix/eureka` — a Gradle-based service registry with
~409 Java files. Rich domain: `InstanceInfo`, `EurekaClient`, `Application`,
lease management, replication. Deep enough that an agent has to explore to
answer cross-cutting questions.

From the demo root, open two terminals side by side and launch:

```bash
# Terminal 1 — No Trigrep
./start.sh no --yolo

# Terminal 2 — With Trigrep MCP
./start.sh with --yolo
```

(Or cd into each lane's repo dir and run `./start.sh --yolo`.)

### How the lanes differ

- **no-trigrep**: `claude --strict-mcp-config --mcp-config empty-mcp.json` —
  zero MCP servers, including user-scoped ones. Agent falls back to grep + read.
- **with-trigrep**: `claude --strict-mcp-config --mcp-config .mcp.json` — only
  the Moderne MCP server loads. Agent uses Trigrep tools for search (see
  `with-trigrep/.../CLAUDE.md` for the guidance the agent sees).

Give Terminal 2 ~15 seconds after the MCP connects — the full tool surface
(`trigrep_search`, `find_types`, `find_methods`, `find_annotations`,
`find_implementations`, `symbols_overview`, etc.) registers progressively as
the MCP server builds the LST. `/mcp` inside the session shows connection state.

### Prompts

Run the same prompt in each terminal:

```
If I modify the InstanceInfo class, what other classes and services would be affected?
```

This is an implicit search question — the agent has to trace `InstanceInfo`
references across the codebase without being told to "search" or "find".

### What to watch

- **No-trigrep lane:** agent spawns subagents, greps for `InstanceInfo`, reads
  files to confirm types, greps again. In testing: **84 tool calls**, including
  a subagent with 82 calls.
- **With-trigrep lane:** agent composes `find_types InstanceInfo`,
  `trigrep_search`, semantic filters. In testing: **7 tool calls**, no subagent.

### Expected results

From our test run:

| | Without Trigrep | With Trigrep |
|---|---|---|
| **Total tokens** | **4,388,922** | **270,959** |
| Tool calls | 84 | 7 |
| Subagents spawned | 1 | 0 |
| **Reduction** | | **16x fewer tokens** |

### Measure

After both sessions finish, grab each session ID (`/status` in Claude Code)
and compare:

```bash
./session-tokens.sh <no-trigrep-session-id>
./session-tokens.sh <with-trigrep-session-id>
```

---

## 4. Wrap-up (2 min)

> Fast search and deep search are complementary. The multi-repo CLI demo is a
> human workflow — you're searching a portfolio, then narrowing a recipe run.
> The MCP demo is an agent workflow — Trigrep replaces the read loop.
>
> Different users, different cadences, same LST infrastructure underneath.

Optional teaser for the Summit talk: "At Summit in May I'll stitch this
together with the semantic search recipes from last episode — the full
picture of how search and transformation share a substrate."

---

## Troubleshooting

- **`mod search` returns "No search index"**: LSTs built but trigram indexes
  weren't. Run `mod postbuild search index <path>`. If you ran
  `./init.sh --skip-index`, that's intentional — run the postbuild live.
- **`mod search` returns nothing (and no "No search index" message)**: LSTs
  weren't built. Re-run `./init.sh` or `mod build <repo>`.
- **`--last-search` errors**: run a `mod search` first in the same working
  directory; `--last-search` reads from CLI state in `~/.moderne/`.
- **Agent in with-trigrep/ doesn't use MCP**: check `.mcp.json` exists and
  `mod mcp` is on PATH. Re-launch `claude` — MCP servers are registered at
  startup.
- **MCP tools show only `build_status`**: give it 15-30 seconds. Tools
  register progressively as the MCP server builds the LST internally. Use
  `/mcp` to check status.
- **Build failures on clone**: some repos need JDK 17+ and Maven/Gradle. Run
  `./init.sh --skip-build`, then build individual repos by hand.
