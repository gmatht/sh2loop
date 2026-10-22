# Verifying shIR→shIR transforms

Three tiers, by what is actually provable. Nothing here claims the transform
layer *preserves bash semantics* — see "Why not the full pipeline" below.

| Tier | Property | Needs shell semantics? | Status |
|---|---|---|---|
| 1 | analysis soundness: "verdict ⇒ fact" | no | **landed** for `div-mod-pow2` |
| 2 | structural/rendering laws over every transform | no | **landed**, `tests/transform_laws.rs` |
| 3 | semantic preservation `⟦f(p)⟧ = ⟦p⟧` | yes | out of reach; differential only |

## Tier 1 — `proof/` next to a manifest

A manifest's `invariant:` line is prose. For a transform whose obligation is
*purely arithmetic* — the analysis-only ones, which compute a verdict and
mutate nothing — that prose can be a theorem:

```
core-requests/transforms/<id>.rs/proof/
  ROOT            isabelle session, pure HOL, quick_and_dirty = false
  Invariant.thy   the analysis predicates, mirrored VERBATIM from the Rust,
                  + the soundness lemma
  README          `isabelle build -D . <session>`
```

Manifest line: `proof: proof/Invariant.thy#<theorem> (checked|stated)`;
`checked` means a build was run, `stated` means it was not. A false `checked`
claim is the thing to catch.

First artifact: `core-requests/transforms/done/div-mod-pow2.rs/proof/` proves
`div_mod_pow2_sound` (`non_negative e ⟹ 0 ≤ eval e`) plus `pow2_pos`,
`non_negative_bin_iff` and `shift_agrees`. Being analysis-only, that lemma is
the transform's *entire* obligation. It is `checked` with Isabelle2025-2, and
a negative control was run and failed — a session that only ever passes is
not evidence.

Rule for what belongs in `proof/`: the theorem statement may mention only
IR-shaped data (expressions, intervals, name sets). If it needs `⟦·⟧` of a
*statement*, it is Tier 3 and does not belong here.

## Tier 2 — `tests/transform_laws.rs` (the workhorse)

Property tests over every transform in `transforms::all()`, each run in
isolation (only that name in `SH2_TRANSFORMS`) on its own copy of a generated
program. No shell semantics, so a green run is a statement about shapes, not
about meaning.

Four laws:

1. **determinism** — `f(p)` is a function of `p`. Verdict statics are reset
   before every run (`transforms::reset_verdicts`); without that, run 2 sees
   run 1's verdict and the law is vacuously true. Transforms that allocate
   fresh names from a process-global counter (`text-ops`: `__sv<K>_<i>`) are
   compared after a canonical renaming.
2. **idempotence** — `f(f(p)) == f(p)`, except transforms declared
   `SINGLE_PASS` in the harness, each with a stated reason.
3. **forbidden-shape** — the transform's declared invariant in executable
   form ("no foldable `${v:0}` survives", "no foldable `${#NAME[@]}`
   survives", "no literal-pattern `case` survives", …). Only transforms with
   a *real* predicate get a row: one that returns `None` passes on every
   input without testing anything.
4. **perl-invariance** — `shir_to_perl(f(p)) == shir_to_perl(p)` for
   transforms declared `RENDER_EQUIV` — **value**-preserving folds whose
   rendering is unchanged. A fold whose *node shape* changes
   (`param("slice", …)` → `param("")`) is deliberately not listed.

### Coverage is part of the verdict

The harness prints how many transforms actually *rewrote* a generated
program, and names the idle ones. A law that never fires proves nothing, so
"8/48 rewrote something" (cases=128; the count moves a little with the
seed) is reported next to "4 laws passed", not omitted. The idle set is the
roadmap: it needs richer generated shapes (capture `env`, redirects,
`Pipeline`, `Ext`), and the list is printed, not hidden.

Known exclusions from the generator: `Ext` (boxed trait object),
`Json(serde_json::Value)`, `RawText`, `Asm`, `Select`, `Try`, `Shaderize`.
The generator is depth-bounded (`MAX_DEPTH`) because the IR types have no
`Drop` glue: an `IrExpr` chain ~1500 deep overflows a 64 MiB stack **while
being dropped**, before any law is checked.

Two shapes are **guaranteed** in every generated program — a foldable
`${v:0}` and a foldable `${#NAME[@]}` — because proptest's shrinking prefers
short, leaf-heavy programs and would otherwise let the forbidden-shape law
pass without ever having an instance to fold (measured: with random draws
only, that law passed while the suppressed fold went unnoticed).

### Proof that the gate can fail

The forbidden-shape law was probed by making `run_one` restore the input after
the call (i.e. pretend the fold did nothing) for `array-len-fold` and, in a
separate run, for `slice-identity`:

```
LAW forbidden-shape FAILED: `array-len-fold`: a foldable `${#NAME[@]}` param("slice") call survived
LAW forbidden-shape FAILED: `slice-identity`: a foldable zero-offset/empty-length param("slice") call survived
```

Reproducible in 3/3 runs for each. A law that cannot fail is not evidence.

### Found by the harness

- **`text-ops` / nested subshells.** A `Subshell` inside a `Subshell` was
  copied into the outer snapshot/restore block verbatim, so the second run
  wrapped the inner one again with a fresh counter index and a different
  variable ordering: the inner save no longer read the outer save's restored
  value. `lower_stmt` now lowers the body in the same call. (Fixed in
  `src/transforms/text_ops.rs`.)
- `copy-propagation` skipped reads carried in flat `test`/`arith` text,
  leaving declare+assign+never-read variables in the Perl output (fixed on
  `main`, 506 → 511 text-identical).
- Two render-equivalence claims were **false**: `interp-fold` (the rewritten
  `DoubleQuoted` style tag is load-bearing, so the Perl text differs) and
  `slice-identity` (equal value, different rendering).

## Tier 3 — why not prove the pipeline

`transforms::apply()` is not a function to state a theorem about: eight
transforms keep verdicts in `static Mutex` read back by *renderers*, one
allocates fresh names from a process-global counter, and the IR is untyped
(`Call { func: "setVar" | "param" | … }` as a string-keyed runtime seam,
`RawExpr`, `RawText`). The meaning a transform must preserve is bash's — IFS
splitting, `${v:0}` on scalar vs array, `set -u` — and there is no formal
semantics of that to quantify over. The honest cheap oracle for this tier is
differential: `shir_to_perl(f(p)) == shir_to_perl(p)` (law 4) and
`harness/transform-diff.sh` over the corpus.

## Running it

```
cargo test --test transform_laws                      # the laws themselves
PROPTEST_CASES=256 cargo test --test transform_laws   # more cases
harness/transform-laws.sh                             # gate form, per-law report
harness/transform-laws.sh --cases 256 --json
harness/transform-diff.sh                             # corpus differential
```

`transform-laws.sh` builds into `$WT/target-transform-laws` unless
`SH2_TARGET_DIR` says otherwise: the shared target on this box has been
stale/racy, and a gate that silently tests an old binary is worse than no
gate.
