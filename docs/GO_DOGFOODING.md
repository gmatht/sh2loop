# Go Dogfooding: `frontends/go-sh` → Equivalent JS

**Goal:** `frontends/go-sh` transpiling its own sources (`shir-emit-go/emit.go`
+ `cmd/go-sh/main.go` + `go-sh.go`) to estree JS, with the JS CLI producing
byte-identical A1 (`--shir --raw`) to native `go-sh` over `testdata/*.go`.
Gate: `./fail-go-app` (oracle `go-sh --shir`, JS via `otranspilerl
--source-lang shir --target estree` + `estree-runner.mjs`).

**Scoreboard (2026-09-12):** 26/124 pass. All 26 are straight-line
(literals, assigns, echo, arith, string ops, imports, type decls — no `if`,
no value-`return`, no composites, no value-calls). Everything with control
flow, values, or composites fails. Plus 11 minimal repro patterns verified
byte-identical during this effort (m1–m7, m9–m11, m25) and t01–t04 green.

**Merge status:** all dogfood commits are on `master` (8 code + 4 doc).
Isolation branch `dogfood/go-sh-value-channel` exists as worktree
`/home/llm/sh2loop-dogfood` (verified: builds, t01 green there). Intended
as the joint-validation branch for shared fixes (see §4).

## 1. Shared transpiler (`otranspilerl` shir→estree) — owner: transpiler

These block the most tests; each is filed with repro + mechanism in
`core-requests/dogfood-20260911-value-channel-blockers.md`.

1. **Value-channel calls.** Helper calls in spread/append/argument position
   lower to `fnCall`-status, discarding returned maps/slices (direct
   assignments that survive use `exec`+capture). Breaks: `if` emission
   (`condToJSONIf`), return echos (`execStmt`), composite assigns
   (`assignStmt`), capture construction. Frontend works around per-site by
   inlining literals; the general fix (pass-by-id or value returns) is
   transpiler-owned. 28 `fnCall`+`jsonObject` sites observed.
2. **Materialization inconsistency.** Identical inline map literals become
   `objNew`/store (survives), `jsonObject`-plain (String-flattens on echo),
   or assoc-temps (name doesn't resolve as field) depending on depth
   (2-deep survives, 3-deep flattens) and position (append/return vs
   standalone var which DCE-drops or flattens). Needs consistent store
   materialization.
3. **Bool protocol.** Go `false` echoes as `"false"` (truthy/non-empty), so
   `if !flag` never fires and `ok &&` passes on refusal. Needs `=="true"`
   checks or empty-on-false echo. Blocks all `ok`-gated routing (`==`).
4. **Nil handling.** Go `x == nil` (nil map) → `"" == ""` (always true);
   Go nil slice → `[]` not JSON `null` (m12/t107 exec `elements`). Needs
   proper nil lowering (and freezeStmts null-restore for nested empties).
5. **Length lowering.** `${#p.toks[@]}`/`#words` on list-held vars gave
   id-string length (fixed runtime-side for `#name`; `[@]` form still
   emitted by frontend paths). `len()` must route to `listLen` for lists
   uniformly (arith/test/cond positions).
6. **Range loops.** `for _, e := range slice` iterates text lines
   (`strSplit(getVar)`), so multi-element lists iterate once (t107 lost
   slot 2). Must iterate items like C-style loops do. (Indexed-`for`
   rewrite produced no loop at all — reverted.)
7. **`:=`-append base.** `out := append(preEcho, X)` lowers with the
   assignee as base (drops `preEcho`). Frontend works around via aliasing;
   proper fix is base-faithful lowering.
8. **Param mapping.** Go param `e` mapped to store var instead of
   positional (renaming fixed it). Short/generic param names need audit.
9. **DCE of map vars.** Standalone map vars vanish (`execNode` came out
   `""`) while nested ones survive. DCE must not drop live maps.

## 2. Shared runtime (`harness/sh2-namespace.mjs`) — owner: runtime

- **Assoc-name resolution.** `"__tmp_m1300"` embedded as a field stays a
  literal string (only `obj#`/`list#`/`assoc#` IDs resolve). Either resolve
  temps at embed or echo IDs. Blocks all `BinOp` conds (m21/m26/m27).
- **Echo-text → object.** Helpers echo JSON text; embedders need objects
  (m24/m28 present-with-text, m29 triple-escaped/invalid). Needs parse-on-
  embed or ID-echo protocol.
- **Escape safety.** Protocol text (`"false\nids"`) in stmts serializes
  with a raw newline → INVALID JSON (m8). Serializer must escape strings
  even when shape is wrong (validity safety net).
- **Done (no action):** `objFieldLen` helper; `objNew("list")` real lists +
  `_serObj` `[...]`; `#name` list lengths; `Str`-value JSON preservation.

## 3. Frontend (`frontends/go-sh`) — owner: go-sh worker

- **Struct-literal lookahead** (NEW, triaged 2026-09-12): `&T{x: "hi"}`
  fails in assign (loud: `unsupported statement starting with hi`, s1)
  AND return (silent empty, s3) positions. Likely a `structLitAhead`
  predicate gap mirroring the fixed `sliceLitAhead`. Self-contained.
- **Composite-assign residuals:** m12 top 1 needs nil-slice (§1.4); top 2
  needs deep-nest (§1.2). No further frontend action identified.
- **Extern/concurrency triage:** `exec.Command` (s2 → `[[]]`), goroutine/
  `chan`/`select`/`defer` (t44/t79, 4+1+1+1 files), interfaces + type
  assert/deref (t84/t100/t101), maps (t103). Each needs minimal-repro
  attribution (construct gap vs shared channel) — s1/s2 pattern to follow.
  **Refusal parity** required throughout: native `failf` refusals must
  match JS refusals byte-for-byte (including stderr + exit), not just
  successes. The `failf`-loud work (fail-closed panics) is the mechanism;
  audit that every frontend `failf` is loud in JS.
- **Proven green (guard):** `switch` (t31/t70 identical), lexer paths,
  member-length, numeric comparisons, arith typing. Any shared change must
  re-verify these (two regressions caught this turn by t01 alone).

## 4. Process: making dogfooding independent

- **Joint-gate merge rule (proposed):** changes touching shared surface
  (transpiler/shir/runtime/contract) must attach green gates for EVERY
  consuming backend, run together from one branch, before landing. Backend-
  local fixes keep flowing independently (existing discipline). This turns
  filed requests into mergeable units and stops fix-one-break-another
  oscillation. Precedent: `wip/merge-frontend-backend-20260907`.
- **Worktree workflow:** one worktree per cross-cutting effort
  (`/home/llm/sh2loop-dogfood` template: branch, otranspilerl binary
  symlinked from main tree, `go-sh` rebuilt locally, `/tmp/dogfood`
  absolute paths shared). Demonstrated: full gate runs isolated from
  main-tree churn.
- **Methodology notes (hard-won):** always byte-compare (count-only
  "passes" masked m1/m7/m28 reds); regenerate bodies after EVERY source
  change (stale bodies caused phantom regressions twice); line-anchored
  probes drift across regenerations (use function-anchored); return
  probes must PREPEND (appended ones are unreachable); `qrun` harnesses
  in `/tmp/dogfood` assemble `prog.mjs` from cached bodies + live ns.
- **Sequencing:** value-channel (§1.1) unblocks the most (ifs, returns,
  multi, composites — ~70 inputs); resolution (§2.1–2.2) + bool (§1.3)
  unblock conditions (~30 with `if`); nil/range/escape (§1.4/1.6/§2.3)
  unblock multi-value + validity; frontend triage (§3) proceeds in
  parallel throughout (independent).

## Discussion

**Why frontend-local saturated:** every tractable shape (literals,
straight-line nodes, test-strings, IDs) is fixed — 9 patterns green from
zero. What remains needs *values* to cross helper boundaries (maps via
calls, text→object, bool/ok semantics, nil/empty distinction, item
iteration, escaping), which only shared-component changes can provide.
Further inline rounds would either not flip tests or risk native A1 shape
churn for other backends (tried twice, reverted twice — see request doc).

**Shape-stability risk:** several proper fixes change emitted shapes
(test-string → `BinOp`, `[]` → `null`, assoc-names → IDs). Each needs
owner blessing with cross-backend gate visibility, not unilateral action
— the joint-gate rule (§4) exists precisely for this.

**What "done" looks like:** `fail-go-app` 124/124 with t01–t04-style
stability (no regressions on shared changes), refusal parity for
out-of-subset constructs (`go`/`chan`/unsupported), and this doc retired
into per-backend maintenance.
