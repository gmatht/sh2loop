# Meaningful compiler-generated temp names

The C backend hoists many compiler-generated temporaries into the emitted
source. Historically they were opaque (`_cn3`, `_v12`, `_s11`), which made
reading the generated C hard: a reader could not tell what a temp held or
where it came from. This document explores the design space for naming
these temps and records the heuristic the backend uses.

## Goals

A good temp name should be:

- **Distinctive** — it hints at what the value is / where it came from
  (e.g. `_cn_af_10` reads as "the result of `all_factors(10)`").
- **Unique** — no two temps in the same scope collide. Uniqueness is
  decided *case-by-case*: the name must be a valid C identifier and must
  not shadow a user variable or another temp.
- **Concise** — not so long that it drowns the surrounding code.
- **User-meaningful** — a reader can guess the call/expression from the
  name without looking it up.
- **Stable** — a small source edit (adding a variable in the middle) does
  not renumber unrelated temps, so the generated C has minimal diff noise.

These goals trade off against each other: meaningfulness wants more
information, conciseness wants less, distinctiveness wants values,
stability wants names.

## Design space

A temp name is built from a few orthogonal dimensions:

| Dimension | Choices |
|-----------|---------|
| **Function name** | full (`all_factors`), abbreviated (`af`), or omitted |
| **Arguments** | values (`10`), names (`n`), abbreviated (`6_x6_`), hashed (`8f3a`), or omitted |
| **Uniqueness** | sequence counter, derived from the args, or a hash |
| **Prefix** | `_cn_`, `_`, or none |

## When is each signal appropriate?

The name should answer *"which call is this?"* The best signal depends on
the call:

### Seq numbers vs arguments

| Signal | Pros | Cons | Appropriate when |
|--------|------|------|------------------|
| **Seq** (`_cn_3`) | always unique, concise, stable | opaque — reader must look up the definition | the call is not meaningful to a reader (generic helper, complex/opaque args), or as a collision fallback |
| **Arguments** (`_cn_af_10`) | distinctive — reader can guess the call | can be long, can collide, unstable (change when args change) | the args are short literals that identify the call |

The seq is a *fallback*, never the primary signal: it guarantees
uniqueness when nothing else distinguishes the call.

### Argument names vs values

| Signal | Pros | Cons | Appropriate when |
|--------|------|------|------------------|
| **Value** (`_cn_af_10`) | distinctive — identifies the exact call | unstable — changes when the value changes | the arg is a short literal |
| **Name** (`_cn_af_n`) | stable — does not change when the value changes; meaningful if the variable is descriptive | less distinctive — does not distinguish `all_factors(10)` from `all_factors(12)` if both are `n` | the arg is a variable with a meaningful name |

So: **literals → value** (distinctive), **variables → name** (stable).
This is the direct answer to the stability concern: a call whose argument
is a variable keeps its name when the variable's value changes.

### Abbreviated vs full

| Signal | Pros | Cons | Appropriate when |
|--------|------|------|------------------|
| **Full** (`_all_factors`) | meaningful, unambiguous | verbose | the name is short, or the abbreviation would be ambiguous |
| **Abbreviated** (`_af`) | concise | lossy — cannot recover the full name; ambiguous (`af` = `all_factors` or `array_find`) | the name is long *and* the abbreviation is recognizable (first letters of words, like `strlen`) |

Abbreviating a short name (`greet` → `g`) loses meaning and is never
appropriate.

### Complex args: first-n-chars + ellipsis vs hash

A complex argument (a long expression, a nested call) cannot be shown
verbatim. Two ways to shorten it:

| Signal | Pros | Cons | Appropriate when |
|--------|------|------|------------------|
| **First-n-chars + `_`** (`_cn_af_67108847_`) | meaningful — the reader sees the beginning of the expression | not unique — same prefix collides (the seq handles it) | the expression has a meaningful prefix (a literal operand, a recognizable call) |
| **Hash** (`_cn_af_xac6f`) | unique, fixed length | opaque — the reader cannot tell what the expression was | the expression has no meaningful prefix (a long nested call), or is very long |

Decision rule: if the expression contains a meaningful literal (a number
or short string), show it + `_`; otherwise the prefix would be opaque
anyway, so hash. The seq fallback guarantees uniqueness in both cases.

## The runtime heuristic

For a native call `f(a1, a2, …)` the backend builds a name as:

```
_cn_<fn-part>_<arg-part>_<seq?>
```

- **fn-part**: the callee name, abbreviated when long. A name of 4
  characters or fewer is kept whole (`greet` → `greet`); a longer name is
  reduced to the first letter of each underscore-separated word
  (`all_factors` → `af`, `small_factors` → `sf`).
- **arg-part**: each argument is rendered to a short form, choosing the
  signal by arg shape:
  - a small integer literal is kept verbatim (`10` → `10`);
  - a short string literal, or any numeric string (shell values are
    strings, so `2147483645` arrives as `Str`), is kept verbatim;
  - a variable keeps its NAME (`n` → `n`) — stable across value changes;
  - a complex expression keeps its first literal operand + `_`
    (`67108847LL * 67108837LL` → `67108847_`) when it has one, else a
    short stable hash tag.
- **seq**: appended only when the base name would collide with an already
  used temp in the same function, or when the base name is empty. The
  used-name set and the seq counter are **per function**, so adding a
  variable in one function does not renumber another function's temps.

### Why this shape

- **Distinctive**: the callee name (or its abbreviation) is always
  present, so the temp reads as "the result of calling `f`".
- **Unique**: the per-function seq fallback guarantees no collisions; the
  arg-part makes distinct calls to the same function distinct even without
  the seq.
- **Concise**: long function names and complex args are abbreviated.
- **Meaningful**: short literal args are preserved, so `_cn_af_10` tells
  you the call was `all_factors(10)`; variable args keep their names, so
  `_cn_af_n` tells you the call was `all_factors(n)`.
- **Stable**: the base name is a pure function of the call (not the render
  order), and the seq counter is per function — a small edit in one
  function does not renumber another's temps.

### Examples

| Call | Name |
|------|------|
| `all_factors(10)` | `_cn_af_10` |
| `all_factors(12)` | `_cn_af_12` |
| `all_factors(2147483645)` | `_cn_af_2147483645` |
| `all_factors(n)` | `_cn_af_n` |
| `all_factors((67108847LL * 67108837LL))` | `_cn_af_67108847_` |
| `greet("world")` | `_cn_greet_world` |

## Trade-offs and open questions

- **Arg abbreviation is lossy.** A complex arg is reduced to a tag, so the
  name no longer encodes the exact value. This is the price of
  conciseness; the seq guarantees uniqueness regardless.
- **Abbreviation collisions.** `all_factors` and `array_find` both
  abbreviate to `af`. The seq (or the arg-part) disambiguates them.
- **Stability vs distinctiveness.** Arg values are distinctive but
  unstable; arg names are stable but less distinctive. The heuristic
  picks by arg shape: literals get values, variables get names.
- **Stability across runs.** The name must be deterministic for a given
  program so the output is reproducible. The base name is a pure function
  of the call, and the per-function seq follows the render order within a
  function (stable as long as the calls before it do not change).
- **User-variable shadowing.** A temp must not collide with a user
  variable. The seq fallback (and the `_cn_` prefix, which user code
  rarely uses) keeps temps out of the user's namespace.

## Scope

This heuristic currently applies to:

- **Native function-call result temps** (`_af_10` in C) — the shared
  `naming::temp_base_name` heuristic.
- **Float-path temps** (`__h_int_0` — the frontend tags the hoisted
  expression's first identifier instead of the opaque `__fl0`; the `h`
  prefix means "hoisted", since the value is a `long long`, not a
  float).
- **Positional-param temps** (`p1` — the positional index is the signal;
  `naming::param_temp_name`).

The other temp families (`_v` vbuf, `_s` snprintf, `_ret` return, `_ai`
array-index, `_sv` saved-var) are more generic and harder to give
meaningful names; extending the same idea to them is possible but lower
value.
