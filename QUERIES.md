# Trigrep query catalog

Queries to rehearse and run live. Each entry shows the Trigrep query, what it
demonstrates, and — where useful — the grep contrast that exposes why Trigrep
wins.

Every `mod search` call needs a path as its first argument. From
`multi-repo/`, use `.`. From elsewhere, give an absolute path.

Supported semantic filters: `extends:`, `implements:`, `visibility:`,
`type:method`, `type:symbol`, `throws:`, `returns:`. Structural patterns use
the `struct:` prefix (Comby syntax). **Not supported:** `type:annotation`.

> **CLI 4.1.6 note:** boolean composition (`AND`/`OR`/`NOT`), `file:` / `path:`
> / `lang:` filters, and `-file:` / `-f:` exclusions are documented on the
> website but do not currently parse in `mod search` — they silently return
> zero matches. Use separate queries and filter the output, or use `struct:`
> patterns for multi-token matches. Filed to engineering.

Sourcegraph is the default syntax. Zoekt is available via `--syntax=zoekt` if
that's your muscle memory, but it's strictly cosmetic in practice — and its
bare-regex support is partial in CLI 4.1.6 — so all examples below stay on
Sourcegraph.

> **Symbol-lookup caveat:** the Sourcegraph-native form
> `'"Foo"' type:symbol` parses but leaks into non-code files (README.md, etc.)
> in CLI 4.1.6, and the regex variant `'/Foo$/' type:symbol` silently returns
> zero matches. Prefer `sym:Foo` / `sym:/Foo$/` — works in both syntaxes and
> scopes to `.java`.

---

## Tier 1 — Familiar syntax (warm-up)

_Open with these so the audience sees "you already know this query language."
All are fast — pick whichever lands best with the audience._

### Literals

_Plain text scans — the kind of thing you'd reach for grep for. Notes, URLs,
license headers, debug artifacts left behind._

```bash
mod search . '"TODO"'                            # TODO comments across the working set
mod search . '"FIXME"'                           # FIXME comments
mod search . '"Copyright"'                       # license headers
mod search . '"localhost"'                       # hardcoded dev URLs
mod search . '"System.out.println"'              # debug prints someone forgot
mod search . '"password"'                        # scan for the word password (config, messages, docs)
```

### Regex

```bash
mod search . '/find\w+By\w+/'                    # finder method names
mod search . '/save\w*/'                         # save, saveAll, savedItems…
mod search . '/Test\w+/'                         # classes/tokens starting with Test
mod search . '/(Abstract|Base)\w+/'              # alternation — base classes
mod search . '/ERROR|FAILED|Exception/'          # error/exception mentions
```

### Symbol lookups

`sym:` works in both syntax modes — use it everywhere.

```bash
mod search . sym:ClinicService                   # class symbol
mod search . sym:findOwnerById                   # method symbol
mod search . sym:Owner                           # any symbol named Owner
mod search . 'sym:/Repository$/'                 # regex symbol — all Repository classes
mod search . 'sym:/Abstract\w+/'                 # every Abstract* symbol
```

### Grep contrast (optional)

```bash
grep -rn "RequestMapping" .
```

Grep returns every import line, every usage, every comment. Trigrep's symbol
search returns just the declarations.

---

## Tier 2 — Semantic filters (the differentiator)

_The moves grep and Sourcegraph can't make. Each is an LST-aware query that
would require AST parsing to replicate by hand._

### Disambiguation: which `StringUtils`?

```bash
mod search . sym:StringUtils
```

Expected: a handful of `StringUtils` classes across repos. The symbol filter
shows declarations, not every call site.

Grep contrast:

```bash
grep -rn "StringUtils" . | wc -l
```

Grep drowns you. The point lands: "symbol search knows what a class is."

### Inheritance: who extends `Person`?

```bash
mod search . extends:Person
```

Expected: `Owner` and `Vet` in multiple petclinic variants. Narrate how each
petclinic flavor (JSP, REST, reactive, framework, microservices) has its own
`Person` hierarchy — Trigrep finds them all without you needing to know where.

Grep cannot do this.

### API surface: public methods

```bash
mod search . visibility:public type:method returns:ResponseEntity
```

Every public method returning `ResponseEntity` across the working set — in
one query. Useful framing for the `--last-search` bridge below.

### Exception surface

```bash
mod search . throws:IOException type:method
```

Methods that declare `throws IOException`. Useful for "what would a
checked-exception migration touch?"

### Interface implementations

```bash
mod search . implements:Repository
```

---

## Tier 3 — Structural search (`struct:` / Comby)

_When a query needs to match code structure that spans multiple tokens or
lines, use a structural pattern. `:[hole]` placeholders match balanced
delimiters (parens, braces, brackets, strings), so the match respects code
shape instead of fighting it with regex._

### Simple API usage

```bash
mod search . 'struct:System.out.println(:[msg])'    # ~82 matches: every println call
mod search . 'struct:@RequestMapping(:[args])'      # ~21 matches: annotation invocations with args
```

Grep contrast: `grep -rn 'System.out.println' .` catches the same calls, but
can't tell you what's inside the parens. `:[msg]` captures it and respects
nested calls and strings.

### Code smells (the "find refactoring candidates" move)

```bash
# Empty catch blocks — classic anti-pattern
mod search . 'struct:catch (:[type] :[e]) { }'

# Any catch body — swap in a precise pattern once you see what's there
mod search . 'struct:catch (:[type] :[e]) {:[body]}'

# Index-based for loops that could be enhanced for-each
mod search . 'struct:for (int :[i] = 0; :[i] < :[list].size(); :[i]++) {:[body]}'
```

### Constructor and API call patterns

```bash
mod search . 'struct:new :[type](:[args])'          # every constructor call (~1.2k matches)
mod search . 'struct:new ArrayList<:[t]>()'         # empty ArrayList — Collections.emptyList candidate
mod search . 'struct:.equals(:[str])'               # every .equals(...) call site
mod search . 'struct:Optional.of(:[x])'             # Optional.of call sites
```

Narrate: "Regex can't do this cleanly. A regex for `catch(...) { }` would miss
anything with nested braces or a string literal containing `}`. Structural
holes match balanced delimiters, so the pattern tracks the shape of the code."

### Whitespace gotcha

Struct templates are whitespace-sensitive: `{ :[body] }` (spaces) and
`{:[body]}` (no spaces) are different templates. When a query returns zero
matches, try collapsing the spaces around braces first.

---

## Tier 4 — Bridge to a recipe run (`--last-search`)

_Fast search narrows the portfolio; a recipe does precise, deeper work on
only the repos that matched. The climax of the CLI demo._

```bash
# 1. Search for @RestController declarations.
mod search . sym:RestController

# 2. Run a deeper search recipe only against repos that matched.
mod run . --last-search --recipe=org.openrewrite.java.search.FindAnnotations \
  -PannotationPattern='@org.springframework.web.bind.annotation.RestController'
```

Why this is the story: the `sym:RestController` search is fast but
approximate (it matches any symbol named `RestController` — the annotation
itself, but also any class, method, or field using that name). The
`FindAnnotations` recipe is precise — it only reports actual `@RestController`
annotations on declarations — but it's heavier. `--last-search` scopes the
precise pass to only the repos that matched the cheap one.

Look at the output: "Produced results for N repositories." N is smaller than
the total working set — that's the point.

---

## Single-repo queries (agent demo)

_The Trigrep-enabled agent will compose these on its own via MCP. Rehearse
them by hand first so you know what "good" looks like._

Run from inside `with-trigrep/Netflix/eureka/`:

```bash
mod search . visibility:public type:method                   # public API surface (792 matches)
mod search . sym:EurekaClient                                # core interface
mod search . sym:InstanceInfo                                # central domain class
mod search . extends:AbstractInstanceRegistry                # registry implementations
mod search . throws:IOException type:method                  # exception surface
```

Grep contrast to show the agent's pain:

```bash
grep -rn "InstanceInfo" .
```

Hundreds of hits — imports, comments, test assertions, string constants. The
agent has to read each file to confirm which are actual type references.
Trigrep's structured results skip that work.

---

## Gotchas

- Quote Sourcegraph literals: `'"RequestMapping"'` (single-quoted for the
  shell, double-quoted for the query). Without quotes, Sourcegraph treats
  them as field expressions.
- Boolean composition (`AND`/`OR`/`NOT`), `file:` / `path:` / `lang:` filters,
  and `-file:` / `-f:` exclusions don't parse in CLI 4.1.6 — run separate
  queries or use `struct:` for multi-token matches.
- `struct:` templates are whitespace-sensitive between literal tokens. If a
  structural query returns zero matches, collapse the spaces around braces.
- Recipe options use bare `-PoptionName=value`, **not** `-Poption.optionName=`.
- `type:annotation` is not a valid filter. For annotation structure, use
  `struct:@Thing(:[args])` or the `FindAnnotations` recipe.
- `mod search` needs a path arg — from `multi-repo/` use `.`, or give an
  absolute path.
