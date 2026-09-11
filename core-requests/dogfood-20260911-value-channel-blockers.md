# Dogfood 2026-09-11 — value-channel blockers for go-sh self-transpilation

Scope: `frontends/go-sh` transpiling itself to estree JS (`fail-go-app`
gate). The go-sh frontend fixes in this round are DONE and green
(member-length `len(p.toks)` via `sh2.objFieldLen`, numeric `-lt` family
for int comparisons, `:=` arithmetic typing as Int — t01–t04 still pass,
no regressions). What remains is NOT fixable in go-sh.go: three
value-channel integrity gaps in shared components (otranspilerl
shir→estree + sh2-namespace runtime) that break ALL `if` statements and
ALL value-`return`s in transpiled output (~16+ testdata files, ~70 of the
~98 failing census inputs exercise one or both).

Repros below use the dogfood app; minimal Go inputs included. Filed, not
blessed. Owner: transpiler/runtime (not go-sh).

## 1. Dual-use helpers lose values (if/return emission) — CRITICAL

A Go function returning a slice/map, called DIRECTLY in some places and
via `sh2.exec`+capture in others, satisfies only one convention. The
transpiler lowers direct calls to fnCall+status (JS return DISCARDED) and
exec-calls to stdout-capture (missing echo → EMPTY).

Concrete: `condToJSONIf` (returns `[]map`, the If node) is invoked via
`sh2.exec("condToJSONIf", …)`+capture in parseIf's tail
(`go-sh.go: return append(pre, p.condToJSONIf(…)…)`), but transpiled as
JS-return (no echo) → capture gets `""` → parseIf returns `[]` →
EVERY `if` statement (even `if true { _ = 1 }`, m24.go) lowers to ZERO
stmts (silent, exit 0). Verified: parseIf runs (probe fires), its
`__ret` holds the stmts list (empty), output program has 0 stmts.

Same class: `execStmt("echo", words, …)` (returns the echo node map)
called directly in the value-`return` path → map discarded via
fnCall-status → echo statement LOST (`return 42`, m10.go, yields
`[return, return]` instead of `[echo 42, return]`).

Fix direction (owner's call): EITHER make spread/value-position calls use
the JS-return channel (currently exec+status), OR ensure exec-invoked
helpers echo. Caution: blanket dual-channel (return AND echo) pollutes
outer captures for direct-called helpers (their stdout feeds enclosing
captures) — needs per-call-site convention, not a global switch.

## 2. Empty Go slice → objNew("list") struct (serializes `{}` not `[]`)

`"args": []any{}` (e.g. the bare return-stop node, `go-sh.go` return
path) transpiles to `objNew("list", [], [])`, which allocates a STRUCT
(objNew special-cases only `"map"`; `"list"` falls to struct-kind with
empty fields). Serialization yields `{}` where the oracle has `[]`
(byte-mismatch on every empty-args/empty-elements node). Non-empty
slices lower to real JS arrays (fine) — only the empty case takes the
objNew path (presumably for append-mutability, wrong for fixed empties).

Repro: m10.go `func f() { return 42 }` — oracle return-stop has
`"args": []`, JS has `"args": {}`.

Fix direction: empty fixed slices → real `[]` (or `listNew()` real
lists); reserve objNew-struct only for appended-into temps (or fix
objNew("list") to allocate kind `list`).

## 3. echo of plain objects → "[object Object]"

`builtins.echo` joins args with String coercion. Nodes built via
`jsonObject` (plain JS objects, e.g. the bare-`return` path's
`echo [[jsonObject(…)]]`) flatten to `"[object Object]"` (m6.go: bare
`return` in func yields a `"[object Object]"` body element). The working
paths echo store IDs (`obj#`/`list#`, resolved structurally) — but
anything echoing a plain object corrupts silently.

Fix direction (either): (a) runtime: echo structurally serializes plain
objects/arrays (JSON) instead of String-coercing (bash has no objects,
so no fidelity conflict; `"[object Object]"` is never correct); or
(b) frontend builds store objects everywhere (done for return-stop via
objNew/mapSet; the bare path still uses jsonObject+echo).

## Census impact

With go-sh fixes only (this round): t01–t04 pass (unchanged); m3
(`return []string{"a"}`) now parses (was empty); t110 still red (needs
§1–§3: its `return […]` needs §1, its `if err == nil` needs §1). The ~16
value-return testdata files (t103/t107–t110/t111/t114–t116/t52/t83/t85/
t94/t96/t99) and ALL if-containing inputs need §1; most also need §2–§3
for byte-equality. No go-sh.go action remains for these — verified by
input bisection down to `if true` / `return 42` (m24/m10).
