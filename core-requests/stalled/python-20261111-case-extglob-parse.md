# `case` with an extglob operator in a pattern is silently dropped

**From:** python backend worker (bucket-B pass, 2026-11-11)
**Type:** parser bug, `src/parser/` (single-owner core)
**Blocked:** any `case` whose pattern uses `@(…)` / `!(…)` / `+(…)` / `*(…)` / `?(…)`

Lower priority than `python-20261111-subscript-slice.md`: no example in the
563-file corpus writes it (all extglob use there is inside `[[ ]]`, which the
python renderer now handles). It is filed because the failure is SILENT and
it destroys unrelated statements, so it will not show up as a parse error the
day a corpus file uses it.

## Repro 1 — the whole script vanishes

```sh
case x in @(a|b)) echo ok;; esac
```

`--shir` output:

```json
{"contract_version":1,"stmts":[], …}
```

bash prints `ok`. No parse error, no diagnostic — an empty `Program`. The same
input with an `!(*.txt))` pattern is also empty.

## Repro 2 — the rest of the FILE becomes pattern text

```sh
case $y in
  @(*.md|*.txt)) echo "case1 yes" ;;
  *) echo "case1 no" ;;
esac
case $y in
  !(*.txt)) echo "case2 yes" ;;
  *) echo "case2 no" ;;
esac
shopt -s nocasematch
[[ PYT == pyt ]] && echo "n1 yes" || echo "n1 no"
case PYT in pyt) echo "n3 yes" ;; *) echo "n3 no" ;; esac
```

The rendered python's first `case` gets a discriminant pattern of

```
"@(*.md|*.txt)) echo \"case1 yes\" ;;\n *) echo \"case1 no\" ;;\nesac\ncase $y in\n !(*.txt)) … case PYT in pyt"
```

i.e. the pattern reader consumed every following line (both `case`s, the
`shopt`, the `[[ ]]` tests) up to the last `)` in the file. Everything in
that range is lost.

## Where it looks like it goes wrong

`a|b)` (plain alternation) is correct — `patterns: ["a","b"]`. So the clause
reader splits alternatives on a top-level `|` and ends a pattern on a
top-level `)`, but it does not track **parenthesis depth opened by an extglob
operator**, so:

- `@(a` is taken as one whole pattern, `b)` as another, and the clause `)`
  that closes `@(a|b)`, `)` is consumed as the second pattern's terminator —
  which leaves the reader still "inside" the file and it swallows forward;
- for the single-clause form, the swallow ends at end-of-input and the
  statement is dropped.

Desired: a pattern reader that tracks `(`/`)` depth opened by `@(` `+(` `*(`
`?(` `!(` (and by any `(` inside a brace/extglob group) when splitting on `|`
and when deciding a pattern has ended. The pattern text must reach the IR
VERBATIM — `patterns: ["@(a|b)"]` — because glob semantics are the
renderer's job (the python backend now translates extglob at the match site,
gated on the `shopt -s extglob` state; rust/java/c have their own glob
engines).
