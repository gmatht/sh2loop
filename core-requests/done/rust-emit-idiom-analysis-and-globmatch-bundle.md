# Rust-emit idiom analysis + two proposed cross-backend folds (2026-10-21)

Author: core/general session (Buffy). Scope: analysis of the emitted Rust
across the whole 560-example corpus (`otranspilerl-cli --target rs`, main
checkout build of 2026-10-21 12:20), plus the shared-fold proposals the
analysis points at. This is a SPEC for the marketplace (PLAN §11): the
transforms belong in the shared pipeline; the predicate arms are a bundle
each backend accepts or rejects.

## 1. Measured state of the emitted Rust (560/560 emit, 2.73 MB)

- **`sh2.*` callouts in program bodies: 0.** The rust arm renders native
  Rust; nothing dispatches through the sh2 runtime namespace any more.
  (Prior rust-idiomaticity sessions removed these; PLAN v53-v56.)
- **Dead preamble helpers: 0.** Every `fn __sh_*` in every emitted file is
  called at least once — the helper gate (`add_helper` + the
  `preamble_gates_dead_boilerplate` contract) is fully effective.
- **Casts: 68 `as i64`, 441 `as usize`, 25 `as i32`, 0 `as u32/f64/u8`.**
  The v63 `as u32` purge held. The surviving casts concentrate in two
  render sites, both backend-local templates:
  1. the `${arr[@]:off:len}` element-slice block (rust_backend.rs, the
     `__v[__s..__e]` clamping template — ~6 lines of bounds arithmetic
     per slice site, run even when off/len are compile-time constants);
  2. index/len reads (`__SHV_x.with(|v| v.borrow().len() as i64)`,
     `piece.chars().take(p as usize)`).
- **`__sh_fnmatch` call sites: 207** across 54 files. Top files:
  064_hard_to_generate (14), 063_hard_to_parse (10), 070_gnuisms (9),
  058_advanced_bash_idioms (7), test-glob-rhs-fallback (6). By pattern
  shape (uniq -c over call sites):
  - true globs needing an engine: `i*86`, `!(*.min).js`, `?`, `5.4.*`,
    `*\$\{[^}]*\}*` …;
  - **char-class heads: `[a-z]*`, `[A-Z]*`, `[0-9]*`** (the case_lowering
    refusal class — one class pattern keeps the whole `case` on fnmatch);
  - **plain literals: `x86_64`, `abc`** — these come from the param-
    expansion strip path, not from `case` (see §3).

## 2. Ownership notes (what is NOT proposed here)

- The `"@"` off-slot of `param("slice", name, off, len)` is the
  array-vs-string-slice DISCRIMINATOR (ir.rs:5014, estree.rs:1568/2226,
  shir.rs:11554, c_backend.rs:797, go:1832, rust idx_at, java has_at …).
  It must stay; main's rust arm simply mishandles it in
  `slice_index_expr` (renders the marker as a runtime
  `"@".to_string().trim().parse::<i64>().unwrap_or(0)` chain). The rust
  WORKTREE already carries the `@ → 0` arm; it merges with the rust lane's
  in-flight WIP (+1682 lines uncommitted in main's rust_backend.rs).
- The constant-bounds slice specialization (fold `off/len` literals into
  `__v[..k]` short forms) is a rust-backend template change — same lane.

## 3. Proposed shared work (marketplace bundles)

### A. `globMatch` predicate + case_lowering char-class arm

A `case` whose clause set contains ONE glob-class pattern currently
refuses as a whole (case_lowering.rs `CasePat::Glob(_) => return no(…)`,
pinned by `glob_class_refuses_whole_case`), keeping N fnmatch callouts.
Proposal: a shared predicate call

    Call { func: "globMatch", args: [Str(pattern), value] }

lowered per backend to the backend's own glob engine (rust
`__sh_fnmatch`, C `sh_fnmatch`, estree expandWord-based predicate, perl
`fn(3)`-equivalent regex), and a case_lowering arm that lowers a case as
soon as EVERY clause is exact/prefix/suffix/contains/globMatch — the
class clause becomes one `globMatch` condition instead of forcing the
whole match chain to stay. Soundness: no glob is translated; the pattern
string is passed through verbatim, so refusal rules do not change — only
the DISPATCH gets shared. Backends without an arm keep their native
`case` render (the transform target-gates on the accepting set, exactly
like case_lowering's existing gate). Expected effect: 057-class files
drop from N fnmatch sites per case to 1 predicate per class clause; the
plain-literal and affix clauses of the same case stop paying fnmatch.

### B. Literal/affix strip fast-path (param expansion)

`${v#pat}` lowers to `param("#", var, pat)` and each backend renders it
via its strip helper — and rust's helper table makes `strippre`,
`stripsuf` and `replace` ALL depend on `fnmatch`
(rust_backend.rs:13436 `"strippre" | "stripsuf" | "replace" => &["fnmatch"]`),
so a literal-pattern strip (the common case — `x86_64`, `abc`, `--` in
the corpus) drags in the whole glob engine. Proposal: a shared shIR fold
that rewrites the pattern into the shape each backend already renders
primitively, or a new pair of shared ops `stripPrefixLit`/`stripSuffixLit`
for the provably-literal patterns (no glob metachars after unescaping):

    param("#",  v, "lit")   → remove ONE leading "lit"      (non-greedy)
    param("##", v, "lit")   → remove ALL leading "lit"s     (greedy)
    param("%",  v, "lit")   → remove ONE trailing "lit"
    param("%%", v, "lit")   → remove ALL trailing "lits"
    param("#",  v, "lit*")  → strip_prefix("lit") if present  (shortest)
    param("##", v, "lit*")  → strip_prefix("lit") → "" (whole rest)
    (symmetric for %/%% with "*lit")

Each identity follows directly from glob semantics (`*` matches the empty
string; shortest-vs-longest picks the cut point). Refuse everything else
(classes, `?`, multiple stars, escapes) — the generic helper keeps those.
Effect: literal strips stop depending on fnmatch in every backend whose
helper table mirrors rust's; the fold is testable per-backend against the
existing strip-helper unit tables.

## 4. Verification available for this spec

- The emitted-corpus numbers above are reproducible from
  `otranspilerl-cli --target rs` over `sh2perl/examples/*.sh`
  (harness/fail-rs emits into $RS_GATE_OUT).
- `./fail` (perl corpus gate), `harness/fail-rs` (core-path rust gate,
  baseline 541/12 red/7 skip) and `backends/rust/rt_gate_verbose.sh`
  (worktree rust gate, 645/645) are the equivalence gates for any
  implementation landing from this spec.

## OUTCOME: implemented

Both proposed marketplace bundles are present in the tree (landed in prior
core rounds; re-verified 2026-10-23):

- **A. `globMatch` predicate + case_lowering arm** —
  `src/transforms/case_lowering.rs` emits the shared
  `Call { func: "globMatch", args: [pattern, value] }` and gates it on
  `glob_target_ok()` (estree / rs / rust / java). Render arms exist in
  `src/rust_backend.rs` (condition + call position), `src/java_backend.rs`,
  and the estree side lowers glob classes natively (`CasePat::Glob` in
  `src/shir.rs`). Targets without an arm keep their own case render.
- **B. Literal/affix strip fast-path** — `src/transforms/affix_strip_fold.rs`
  (registered as `affix-strip-fold`, commit 19edab3e5) rewrites the
  magic-free literal `${v#lit}` / `${v%lit}` family to the shared
  `AffixStrip` node, with the verified rust render arm
  (`rust_backend.rs` `"AffixStrip"`).

§1/§2's measurement notes and the backend-local cast/slice templates are
not core actions (they belong to the rust lane). Corpus at this round:
`./fail-estree --gate` = 562/562 green.
