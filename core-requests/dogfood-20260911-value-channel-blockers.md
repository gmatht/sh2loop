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

Frontend-local progress (a34dd0a3): parseIf now INLINES the If-node
literal (no helper call) — If nodes ARE emitted with correct
then/else, but `cond` (from direct `p.condToJSON(cond)`, which rides
exec+capture echo-text) arrives as a JSON STRING instead of a map
(m24: `"cond":"{\"args\":…}"` escaped). What remains for the owner:
make exec-captured JSON text usable as a map in expression position
(auto-parse on embed, a value-channel call op, or condToJSON echoing
an obj# id instead of text). `exprToWord` works because it rides
exec+echo (186 sites); `execStmt`/`condToJSONIf` fail because they
ride fnCall+status — the transpiler's per-callee convention choice
is the mismatch, not the call sites.

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

FIXED frontend-independently (a34dd0a3, no transpiler change needed):
`objNew("list")` now allocates a real kind `list` (was struct-kind:
`listPush` silently dropped, `listLen` stayed 0) and `_serObj`
serializes kind `list` as `[...]` (was `{}`). Non-empty slices already
lowered to real JS arrays — only the empty case took the objNew path.

Repro (now fixed): m10.go `func f() { return 42 }` — return-stop
`"args"` was `{}` (objNew struct), now `[]` (verified via unit probe:
kind=list, push sticks, ser=[]). t86 JS unaffected (zero objNew in
its path — checked).

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

## Update 2026-09-11 (later): frontend-local progress + two new patterns

Since filing, several items were fixed WITHOUT shared changes
(commits a34dd0a3, 8d5d5c61 — all frontend-local or safe runtime
bugfixes). Byte-identical now: `return 42`, `return "a"`,
`return []string{"a"}`, return-types, `x := "a"`, `x := 1`, bare
`return` (m3/m5/m6/m10/m11/m25). Still red: `if` cond shape, composite
assigns, string-ifs. New patterns for the owners:

- `out := append(preEcho, X)` lowers with the ASSIGNEE as base
  (`out = push(out, X)`, dropping preEcho) — worked around via
  alias-then-append, but every `new := append(old, …)` is suspect.
- Go `w["key"]` on helper-built maps reads id strings in JS
  (localVal case study: `w["type"]` on a store id always misses).
  Expr kind/text (objGet) survives; map-`[]` needs store-aware lowering
  (or plain-object inlining) from the transpiler.
- `getVar("#name")` on list# vars fixed runtime-side (counts items).
- Remaining §1: If `cond` arrives as JSON TEXT (needs text→object at
  embed, or condToJSON echoing an id). Remaining §3: composite-assign
  `setArray` node builds as plain object (String-flattens on embed).

## Update 2026-09-11 (later 2): composite assigns green, two more patterns

- `fnCall` String-flattens OBJECT args (`flat.push(String(a))`) AND
  discards map returns — a helper call like
  `assignStmt(x, <node-map>)` corrupts twice (arg becomes
  `"[object Object]"`, return lost). Fixed frontend-locally by
  inlining (m1/m2 green); 28 `fnCall+jsonObject` sites remain for the
  owner (pass-by-id + value returns).
- NO function scoping for shared temps: callee loop `i` clobbers
  caller's live `i` (m7 read `targets[1]`). Fixed at the site via
  save/restore (m7 green); proper per-call frames are owner work.
- `==`/`!=` BinOp via `condOperandA1Word` multi-return under
  investigation (m21 `if err == ""` yields empty cond, poisoning the
  program — one bad node empties output, suggesting fail-closed
  ingress on malformed nodes).
- LESSON (reverted 2026-09-11): `condOperandA1WordInner` REFUSING plain
  vars (`nil,false`) is LOAD-BEARING — accepting them (inline getVar)
  broke t01 (2/2 → 0/2), because callers divert from working fallbacks
  into lossy BinOp paths. Fix the FALLBACKS (test-string), not the
  refusal. m21's `==` never reaches condToJSON at all (parseIf bails
  pre-inline) — the bug is upstream of operand handling.
- LESSON 2 (reverted 2026-09-11): inlining var words in the BinOp
  `!lok`/`!rok` fallback ALSO broke t01 (0/2) despite t01 having no
  comparisons — even unreachable-looking changes to shared condition
  paths regress; the gate is the oracle. Reverted; green again.
- BOOL-STRING protocol (filed for owner): Go `false` echoes as
  `"false"` (truthy/non-empty in JS), so `if !lok` never fires and
  `lok||rok` passes on refusal. ok-gating needs `=="true"` checks
  or empty-on-false echo protocol. Until then, `==`/`!=` with refused
  operands cannot route correctly.
- PARAM MAPPING (filed): Go param `e` mapped to store var (not
  positional[1]); renamed to `operand` (maps correctly). Short/generic
  param names risk mistargeting — owner should verify positional
  mapping for all params.
- NIL-CHECK (filed): Go `x == nil` (nil map) transpiles to `"" == ""`
  (always true). Nil guards on maps always fire; use `!= ""` on
  captured strings instead (works). Owner: proper nil lowering.
- ASSOC-NAME non-resolution (confirmed): embedding `"__tmp_m1300"`
  (assoc temp name) as a node field serializes as the literal string
  (m27: BinOp correctly built in assoc, verified fields, but cond
  stays text). Only obj#/list#/assoc# IDS resolve. Owner: resolve
  assoc temps at embed, or echo IDs instead of names.
- NIL-SLICE (filed): Go nil slice marshals as JSON `null`, but JS
  gives `[]` (m12 top 1: exec Array `elements` null vs []). Nested
  empties need freezeStmts null-restore (or nil lowering). Owner.
- DEEP-NEST materialization (filed): 2-deep Call nesting survives
  (m1 setArray, m10 echo) but 3-deep flattens to `[object Object]`
  (m12 s-distribution listGet chain). Standalone map vars also
  flatten (vs DCE-drop for `=`-assigned). Owner: consistent
  store materialization regardless of depth/position.
