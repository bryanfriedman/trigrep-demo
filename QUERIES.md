# Trigrep query catalog

Queries to rehearse and run live. Each entry shows the Trigrep query, what it
demonstrates, and — where useful — the grep contrast that exposes why Trigrep
wins.

Every `mod search` call needs a path as its first argument. From
`multi-repo/`, use `.`. From elsewhere, give an absolute path.

Supported semantic filters: `extends:`, `implements:`, `visibility:`,
`type:method`, `type:symbol`, `throws:`, `returns:`. **Not supported:**
`type:annotation`.

## Syntax modes

Trigrep supports two query syntaxes via `--syntax`. Same underlying index,
different surface language:

| Goal | Sourcegraph (default) | Zoekt (`--syntax=zoekt`) |
|---|---|---|
| Literal match | `"RequestMapping"` | `RequestMapping` (treated as regex) |
| Regex | `/findBy\w+/` | `findBy\w+` |
| Case-sensitive | `case:yes` | `case:yes` |
| NOT / exclude | `-file:test` | `-f:test` |
| Symbol lookup | `"Foo" type:symbol` | `sym:Foo` |
| Boolean AND | `foo AND bar` | `foo bar` (implicit) |

**The semantic filters** (`extends:`, `implements:`, `visibility:`,
`type:method`, `returns:`, `throws:`) are LST-backed additions and work the
same in both modes. `--syntax` is a muscle-memory toggle, not a capability one.

---

## Tier 1 — Familiar syntax (warm-up)

_Open with these so the audience sees "you already know this query language."
All are fast — pick whichever lands best with the audience._

### Literals

```bash
mod search . '"RequestMapping"'                  # plain literal
mod search . '"@RestController"'                 # annotation-like literal
mod search . '"spring-framework"'                # hyphenated literal
mod search . '"TODO"'                            # comment scan across the working set
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

```bash
mod search . '"ClinicService"' type:symbol       # class symbol
mod search . '"findOwnerById"' type:symbol       # method symbol
mod search . '"Owner"' type:symbol               # any symbol named Owner
mod search . '/Repository$/' type:symbol         # regex symbol — all Repository classes
```

### Boolean composition

```bash
mod search . '"Controller" AND "RequestMapping"' # both tokens in same file
mod search . '"Owner" AND NOT "Test"'            # narrow away test files
mod search . '"Controller" OR "Service"'         # either token
```

### File / path filters

```bash
mod search . '"Controller" file:src/main/'      # only main sources (Sourcegraph)
mod search . '"Repository" -file:test'          # exclude test files
mod search . 'extends:BaseEntity file:model/'   # scope semantic filter by path
```

### Zoekt dialect

```bash
mod search . --syntax=zoekt RequestMapping       # bare literal (same result as quoted SG)
mod search . --syntax=zoekt 'findBy\w+'          # regex bare
mod search . --syntax=zoekt sym:ClinicService    # Zoekt symbol lookup
mod search . --syntax=zoekt 'Controller -f:test' # exclusion with `-f:`
```

Narrate: "Sourcegraph is the default. If your muscle memory is Zoekt,
`--syntax=zoekt` flips it. Same index underneath, just different surface
syntax — audience already knows one of them."

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
mod search . '"StringUtils"' type:symbol
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

## Tier 3 — Bridge to a recipe run (`--last-search`)

_Fast search narrows the portfolio; a recipe does precise, deeper work on
only the repos that matched. The climax of the CLI demo._

```bash
# 1. Search for @RestController declarations.
mod search . '"RestController"' type:symbol

# 2. Run a deeper search recipe only against repos that matched.
mod run . --last-search --recipe=org.openrewrite.java.search.FindAnnotations \
  -PannotationPattern='@org.springframework.web.bind.annotation.RestController'
```

Why this is the story: the literal `"RestController"` search is fast but
approximate (it matches any token that reads "RestController" — imports,
string constants, comments). The `FindAnnotations` recipe is precise — it
only reports actual `@RestController` annotations on declarations — but it's
heavier. `--last-search` scopes the precise pass to only the repos that
matched the cheap one.

Look at the output: "Produced results for N repositories." N is smaller than
the total working set — that's the point.

---

## Single-repo queries (agent demo)

_The Trigrep-enabled agent will compose these on its own via MCP. Rehearse
them by hand first so you know what "good" looks like._

Run from inside `with-trigrep/Netflix/eureka/`:

```bash
mod search . visibility:public type:method                   # public API surface (792 matches)
mod search . '"EurekaClient"' type:symbol                    # core interface
mod search . '"InstanceInfo"' type:symbol                    # central domain class
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
- Recipe options use bare `-PoptionName=value`, **not** `-Poption.optionName=`.
- `type:annotation` is not a valid filter. Use the `FindAnnotations` recipe.
- `mod search` needs a path arg — from `multi-repo/` use `.`, or give an
  absolute path.
