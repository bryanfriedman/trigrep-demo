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

Trigrep supports two query syntaxes via `--syntax`:

- `--syntax=sourcegraph` (default) — Sourcegraph-style: literals in quotes,
  regex wrapped in `/.../`, field filters like `lang:java`.
- `--syntax=zoekt` — Zoekt-style: bare tokens, different regex conventions.

Semantic filters (`extends:`, `implements:`, etc.) work in both modes.

---

## Tier 1 — Familiar syntax (warm-up)

_Open with these so the audience sees "you already know this query language."_

```bash
# Literal (Sourcegraph default — quoted)
mod search . '"RequestMapping"'

# Regex (Sourcegraph — slashes)
mod search . '/find\w+By\w+/'

# Symbol lookup
mod search . '"ClinicService"' type:symbol

# Same literal, Zoekt syntax (bare)
mod search . --syntax=zoekt RequestMapping
```

Narrate: "Sourcegraph is the default. If your muscle memory is Zoekt,
`--syntax=zoekt` flips it." Literal and symbol queries behave the same in
both; regex and field-filter conventions differ.

Grep contrast (optional):

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
