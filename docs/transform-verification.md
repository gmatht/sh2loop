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
program, and names the idle ones.

**Measured against the real corpus too, not only the generator (2026-10-24).**
The generator's "idle" set is about generated shapes; this is the same
question asked of the 562 shell examples, one transform at a time via
`SH2_TRANSFORMS=<name>` and a shIR hash comparison:

| pass | files changed (of 562) |
|---|---|
| `test-lowering` | 43 |
| `array-len-fold` | 9 |
| `const-status-cond` | 8 |
| `const-condition-elim` | **0** |
| `slice-identity` | **0** |
| `affix-strip-fold` | **0** |
| `for-recovery` | **0** |
| `counted-arith-forinit` | **0** |
| `counted-while-forinit` | **0** |

**A zero is only a defect when the pass *should* fire** — and per-pass
counts cannot tell "dead" from "correctly refusing" or "fires only in
sequence". Checked each one against its own guards and against its
neighbours in the pipeline:

* **the native-loop recovery passes** — GENUINE DEFECT (see below). (`for-recovery`,
  `counted-arith-forinit`, `counted-while-forinit`). Corpus-wide, `For`/
  `ForInit` node counts are 49 with transforms OFF and 47 with them ON: the
  passes *remove* two frontend-emitted `For` nodes and recover none. The
  cause for `for-recovery` is recorded in its proof README: `loop_cond`'s
  lowered-comparison arm expects `IrExpr::Var`/`IrExpr::Int` operands while
  the shell path emits them `Arith`-wrapped, and no producer builds the bare
  shape. The sibling passes read the same structured-`Arith` shapes and
  should be checked against the emitted JSON the same way.
* **`const-condition-elim`** — NOT dead, and a first draft of this table
  called it dead by reading its isolated count as 2 when it was 1. On a
  two-line `if true; …; if false; …` probe it folds one `If` and
  `const-status-cond` folds the other; together, in the pipeline order their
  registration enforces (`transforms.rs:316`), both go. The corpus leaves it
  nothing to do because `const-status-cond` runs first.
* **`slice-identity`** — zero because its guards reject the corpus's shapes:
  the live instances are `param("slice","#files","@","")`,
  `param("slice","s","$i","1")` and `param("slice","arr","@","")`, where the
  NAME is not a plain identifier or the offset is not a literal `0`/`""`.
  Those are *not* identities (`${#arr[@]}` is a length, `${arr[@]}` is
  array-vs-string), and `${v:0}` is folded by the parser before the pass
  runs. Correct refusal, not a bug.
* **`affix-strip-fold`** — zero on this corpus; its manifest offers it to
  rs/java targets and the corpus is shell-source, so this is expected —
  though nothing currently distinguishes "rightly zero here" from "broken",
  which is why each entry above needed checking by hand.

The lesson for **proofs** is the same one as for the laws: a Tier-1 lemma
about a pass that never fires is a true theorem about a dead contract. The
`for-recovery` proof in `proofs/ForRecovery/` is exactly that — it is
committed, green, and its README now leads with "the proved path is
unreachable for shell input". Check that a pass fires **before** proving
it, the same way `div-mod-pow2`'s header had to record "no consumer in this
tree". A law that never fires proves nothing, so
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

## Formal node specifications (beyond the laws)

The laws above prove *structural* properties. A separate line of work writes
down what individual shIR nodes **mean** — denotational specs plus proofs
that the lowering emits exactly that meaning. It lives in two places:

| Where | What | Scope |
|---|---|---|
| `proofs/` (`DivModPow2`, `I32Provable`) | analysis-verdict soundness | arithmetic obligations of `div-mod-pow2`, `i32-provable` |
| `sh2perl/docs/fm/TextOps/` | node semantics for `StrLen`, `WordCount`, `RegCount` + `lowered_wc_sound` | the `wc` lowering in `text_ops.rs` |

They are different kinds of claim: `proofs/` proves that a verdict is
**conservative** (marking ⟹ the fact holds); `TextOps` proves that a node's
lowering **denotes the right value** (`wc_count`, with
`strlen_plus_one_is_not_line_count` recording the pre-fix emission as
refuted). Both are Tier 1 — no shell state.

`harness/transform-proofs.sh` builds all of them plus the per-manifest
`proof:` claims — **6 sessions, all green, measured 2026-10-23**:

```
OK      proofs                     (DivModPow2, I32Provable, BigIntRange, IntervalFloor)
OK      proofs/ArithIdentity
OK      sh2perl/docs/fm/TextOps
OK      verif                      (MemorySafety)
OK      …/done/arith-identity.rs/manifest
OK      …/done/div-mod-pow2.rs/manifest
transform-proofs: 6 checked-and-built, 0 stated-only, 0 failed
```

Sabotaging `Invariant.thy` makes it exit 1 on that manifest, and restoring it
(md5 verified) returns to 0 — the gate can fail.

Two things learned building the gate, both of which had produced a PASS over
nothing:

- **Discovery by walking the tree does not work here.** `find` is a shell
  function forwarding to `rg --files` (it ignores `-prune`), the scratch tree
  `sh2loop/` is a 97 GB self-referencing copy of the workspace, and every
  shell-filtered variant of the ROOT list returned zero or everything. The
  gate now names its session directories in `SESSION_DIRS`; a new session is
  added there *and* given a `quick_and_dirty = false` ROOT.
- **Two Isabelle builds must not share `~/.isabelle`.** They corrupt each
  other's source DB (`SQLITE_READONLY_DBMOVED`, then
  `SQLITE_CONSTRAINT_PRIMARYKEY` on the next run), which reads as a proof
  failure. Each build gets a per-run `USER_HOME`; `-c` is not used (it moves
  the shared heap under a concurrent build, and it is the missing `sorry`
  check that matters — `quick_and_dirty = false` is what rejects `sorry`).
