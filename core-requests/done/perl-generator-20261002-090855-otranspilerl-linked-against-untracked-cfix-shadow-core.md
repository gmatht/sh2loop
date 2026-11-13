# otranspilerl-cli was linked against an untracked shadow core, not the gate's source

**Filed by:** the Perl GENERATOR worker
**When:** 2026-10-02 09:08
**Class:** build/infrastructure (not a Perl-generator codegen bug)
**Gate effect:** the `./fail` run measured the WRONG GENERATOR.

## Symptom

The worker prompt says the generator lives in `sh2perl/src/perl_generator_fixed.rs`,
and every Perl-generator commit lands there (`fb2add34c`, `ad3f51ccf`, `a8e7e38c7`, …).
But the binary the gate executes was not built from that file.

`otranspilerl/Cargo.toml` had an **uncommitted local edit**:

```diff
-debashl = { path = "../sh2perl" }
+debashl = { path = "../sh2perl/sh2perl/.cfix" }
```

`sh2perl/sh2perl/.cfix` is a **second git worktree** (`git worktree list`:
`/home/llm/sh2loop/sh2perl/sh2perl/.cfix  ce784092d [c-static-fixes]`) holding a
full independent copy of the crate — `src/perl_generator_fixed.rs`, `src/ir.rs`,
`src/c_backend.rs`, everything. It is **untracked** (`git ls-files` counts 0
entries under `sh2perl/.cfix`), so it exists only on this machine.

Proven from the binary itself, not inferred:

```
$ strings otranspilerl/target/debug/otranspilerl-cli | grep -o '[a-z/]*perl_generator_fixed.rs'
cfix/src/perl_generator_fixed.rs        # ← what the gate was actually running
```

## Why it matters: 7 real fixes were invisible to the gate

`.cfix` sits on branch `c-static-fixes` at `ce784092d`. Main `sh2perl/` is at
`0bf7fed49` and is **7 commits ahead**, including four Perl-generator fixes:

```
fb2add34c perl: stop Fix 13 from re-declaring an already-declared hash
ad3f51ccf perl: stop a glob fix emitting a quoted string, and reach Fix 15 in conditions
a8e7e38c7 perl: an unrebuildable condition rendered as a bare `0` hung the loop
649208694 perl: a `my $a` of ours was shadowing sort's package globals
e3de0a9dd perl: restore the missing eval pass, and stop a post-pass deleting every program
```

So every one of those fixes was committed to `sh2perl/src/perl_generator_fixed.rs`
and **never reached the gate binary**. The gate was grading a stale generator.

## Evidence that it moved the number

Repointing to the committed `../sh2perl` and rebuilding
(`cargo build --manifest-path otranspilerl/Cargo.toml --bin otranspilerl-cli`):

```
before:  503 passed, 55 failed out of 557
after:   503 passed, 54 failed out of 557
```

`008_simple_backup.sh` (backticks around `ls | grep -v a.txt` producing
`b.txt sub1 sub2`) goes green — the fix is in `9df43ab03`/`8dce38e3d`, present
only on main. Verified directly: `perl/src/perl_generator_fixed.rs` now appears
in `strings` output and `cfix/...` does not.

## IMPORTANT — this is NOT a clean win, and the net count hides a regression

Net 55→54 is misleading. Two things moved in opposite directions:

- **Fixed:** `008_simple_backup.sh`
- **Newly BROKEN:** `075_eval_complex.sh` (was passing, now "stdout mismatch")

`075_eval_complex.sh` is `x=42; eval "echo \"The answer is $x\""`. It now emits:

```perl
system('bash', '-c', q{'eval' "echo \"The answer is } . __sh_q($x) . '\\""');
```

`'eval'` is **quoted**, so bash runs a command literally *named* `eval`
("command not found") instead of the `eval` builtin — hence empty output. Note
this same defect is documented at `perl_generator_fixed.rs:1958` as the thing
Fix 7 exists to correct, but Fix 7 did not fire here: `word_source_text()`
(`:2090`) only accepts a payload whose word is `Str` or `Interpolate([Lit])`,
and this payload interpolates `$x`, so the guard bails and the broken call
survives. That is generator work, in my scope — tracked below.

## What I changed

**One line, restoring the committed state** — `otranspilerl/Cargo.toml`
back to `debashl = { path = "../sh2perl" }`. `git diff` is now empty for that
file; I did not invent a new configuration.

## Caveat the operator must decide: `.cfix` is NOT purely stale

`.cfix` is 2 commits *ahead* of main on a different axis — both in
`src/c_backend.rs`, the **C** backend, not Perl:

```
ce784092d c: guard dup() in _sh_capture_fn — a silent stdout-swallowing failure
963a992f3 c: two memory-safety fixes in the emitted runtime helpers, found by gcc -fanalyzer
```

Neither is an ancestor of main `0bf7fed49`, and neither is in the current
`sh2perl/src/c_backend.rs` working tree (which has its own 248-line uncommitted
diff — the core owner's in-flight work, which I did not touch). So pointing
`otranspilerl` back at main **does** stop the C backend from picking those two
fixes up through this crate. That is outside my scope and outside the Perl
gate, so I am reporting it rather than acting on it.

Two possible resolutions, both operator calls:

1. **Delete/retire the `.cfix` worktree** and keep the committed pointer. If
   `c-static-fixes` was a temporary C experiment, this is correct and the two C
   commits should be cherry-picked onto main if they are still wanted.
2. **Make `.cfix` track main** (merge/rebase `c-static-fixes` onto the main
   `sh2perl` HEAD) so it stops shadowing 7 commits, and keep the pointer.

I did **not** do either: removing a worktree and re-pointing the build are both
outside the generator's scope, and `.cfix` may be another worker's live target.

## Also worth knowing (pre-existing, NOT caused by the pointer)

The `.cfix` pointer was set at **08:25**; the binary was rebuilt at **08:47**.
`git status` on the workspace shows `otranspilerl/Cargo.toml` as modified from
before I started. So the shadow build predates this session and other workers
have been measuring against it too.

## Remaining 54 failures are NOT this bug

After the repoint, I classified all 54 (`bash` vs generated `perl`, stdout +
exit + stderr). They are **~24 unrelated root causes**, one per construct —
`eval` payload quoting, `$(( ))` not evaluated (`063_12`: prints the literal
`$(( ${var:-0} + ... ))` instead of `0`), `typeset` routed to coreutils-ffi
(`unknown util 'typeset'`), `coreutils-ffi: unknown util 'eval'`, `$@`/`$*`
losing a leading empty arg, `printf %q` invalid in Perl, `s///` replacement
list longer than search list, `my $a` in a sort comparison, two genuine
timeouts (`065_yes_head_while.sh`, `096_head_procsub.sh` → perl exit 124), and
so on. **No single fix moves that number**; it needs per-construct work in
`perl_generator_fixed.rs`, which is what this worker is for.

## Requested decision

1. Retire `.cfix` (my recommendation — it is untracked, machine-local, and was
   silently grading 7 commits of Perl fixes as nonexistent), or make it track main?
2. Should the two C-only commits be cherry-picked onto main `sh2perl` before
   the pointer is retired?

## OUTCOME: implemented — `otranspilerl/Cargo.toml:16` reads `debashl = { path = "../sh2perl" }`, so the gate links the committed core, not the untracked `.cfix` shadow.
