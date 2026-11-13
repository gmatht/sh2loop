# rust: the gate's rust arm runs both sides in the SHARED corpus CWD — cross-talk fails a faithful cell

## NEED

`setup_backends.sh`'s equivalence gate gives the **c** and **perl** arms a per-cell
scratch dir (`eq_scratch`, line ~1402) and runs BOTH the translation and the bash
reference inside it. The **rust** arm (line 1449) has no such branch: it runs both
sides directly in the caller's CWD, which for the corpus is the shared corpus
directory.

Nine corpus examples write the SAME relative filenames — `file1.txt` / `file2.txt`
appear in `000__04c`, `000__04h`, `000__06`, `017_grep_context`, `062_06`,
`062_hard_to_lex`, `063_14`, `063_hard_to_parse`, `064_16`. Cells run in parallel,
so one cell's `> file1.txt` **truncation** can land between another cell's write and
its read, and the second cell then reads an empty/partial file.

This is a false NEGATIVE: the translation is correct and matches bash when the cell
is run alone, but the gate reports MISMATCH under load.

## WHY — exact location + measurement

`setup_backends.sh:1449` (the rust arm), versus the c arm at line 1432 which has
the `eq_scratch` branch the rust arm lacks:

```bash
# c arm — 1432: both sides inside eq_scratch
cc /tmp/eq_$$.c -o /tmp/eq_$$_bin 2>/dev/null && { if [ -n "$eq_scratch" ]; then (cd "$eq_scratch" && "$KS" ... ); else "$KS" ...; fi; }

# rust arm — 1449: NO branch, both sides in the caller's CWD
rustc /tmp/eq_$$.rs -o /tmp/eq_$$_bin 2>/dev/null && "$KS" timeout -k 2 15 bash -c 'exec -a "$0" "$1"' "$f" /tmp/eq_$$_bin > /tmp/eq_$$_out 2>/dev/null && eq_exit=0 || eq_exit=$?
```

Note the reference run at line 1510-1511 ALREADY honours `eq_scratch`:

```bash
if [ -n "$eq_scratch" ]; then
  (cd "$eq_scratch" && "$KS" timeout 15 bash "$f") > /tmp/eq_$$_ref 2>/dev/null || bash_rc=$?
```

so the reference is scratch-aware while the rust translation is not — the two sides
can even be scored in DIFFERENT directories, which is a second, independent bug in
the same cell.

### The measured failure

`examples/000__04c_text_processing_commands.sh`:

```bash
echo -e "apple\nbanana\ncherry" > file1.txt
echo -e "banana\ncherry\ndate"  > file2.txt
comm_result=`comm -12 file1.txt file2.txt`     # fine
diff_result=`diff file1.txt file2.txt`         # returns EMPTY under contention
```

`ref.out` has the diff hunks; `got.out` has a single blank line. The renderer is
NOT involved — the transpiled binary, compiled and run on its own, produces the
CORRECT hunks. The empty capture is the *other* cell's `> file1.txt` truncation.

Reproduction (the same one cell, 6x in parallel, no isolation): **2/6 MISMATCH**.
With per-cell isolation: **6/6 PASS**. A bare 9-writer loop (no transpiler at all)
hits the same empty-read 5 times in 40 iterations, which pins the mechanism to the
shared filename rather than to any backend.

Three consecutive full runs at `JOBS=6` then read 640 PASS / 0 MISMATCH — i.e. it
is load-dependent and intermittent, which is exactly the signature that makes it
read as a flaky backend rather than a harness defect.

## MINIMAL-CORE-CHANGE

Give the rust arm the same `eq_scratch` branch the c arm has, so BOTH sides run in
the per-cell scratch:

```diff
--- a/setup_backends.sh
+++ b/setup_backends.sh
@@ -1449,1 +1449,1 @@
-                                rustc /tmp/eq_$$.rs -o /tmp/eq_$$_bin 2>/dev/null && "$KS" timeout -k 2 15 bash -c 'exec -a "$0" "$1"' "$f" /tmp/eq_$$_bin > /tmp/eq_$$_out 2>/dev/null && eq_exit=0 || eq_exit=$?;;
+                                rustc /tmp/eq_$$.rs -o /tmp/eq_$$_bin 2>/dev/null && { if [ -n "$eq_scratch" ]; then (cd "$eq_scratch" && "$KS" timeout -k 2 15 bash -c 'exec -a "$0" "$1"' "$f" /tmp/eq_$$_bin > /tmp/eq_$$_out 2>/dev/null); else "$KS" timeout -k 2 15 bash -c 'exec -a "$0" "$1"' "$f" /tmp/eq_$$_bin > /tmp/eq_$$_out 2>/dev/null; fi; } && eq_exit=0 || eq_exit=$?;;
```

`kill-session.sh` already special-cases a `.eq_scratch_*` basename (it descends to
`$PWD/.sh2run/run` so both sides share a stable `..`), so no change is needed there.

Both sides moving together keeps every observable identical: the cell's own files,
`$PWD`, relative paths and `argv[0]` are unchanged. This is exactly the argument the
c/perl arms already document at lines 48-83 of `kill-session.sh`.

Verified locally: the equivalent change in the worktree's own repro harness
(`.gate/run_all.sh` and `.gate/faithful.sh`) takes 000__04c from 2/6-failing to
6/6-passing under 6x parallel self-contention, and leaves the full corpus at
640 PASS / 0 MISMATCH / 0 STUB.

## FAILING-CASE

- `sh2perl/examples/000__04c_text_processing_commands.sh` — `diff_result=\`diff file1.txt file2.txt\`` (capture comes back empty)
- Minimal repro, no transpiler involved:
  ```bash
  # run N of these concurrently in ONE directory
  for i in $(seq 1 40); do
    printf 'apple\nbanana\ncherry\n' > file1.txt
    printf 'banana\ncherry\ndate\n'  > file2.txt
    [ -n "$(diff file1.txt file2.txt)" ] || echo "iter$i: diff EMPTY"
  done
  ```
- Not rust-specific in principle: any arm without `eq_scratch` is exposed. The
  corpus examples that collide are the 9 listed above.

## CORRECTION 1 — a plain `eq_scratch` port for rust would REGRESS 7 cells

The patch above is the shape the c arm uses, but it must **not** be applied to the
rust arm as written. `eq_scratch` is deliberately gated to perl/c only
(`setup_backends.sh:1400-1403`):

```bash
eq_scratch=""
if [ "$g_lang" = "perl" ] || [ "$g_lang" = "c" ]; then
  eq_scratch=$(mktemp -d "$WORKSPACE/.eq_scratch_$$.XXXXXX")
fi
```

and the comment above it justifies it on the premise that **"the corpus is
hermetic: scripts that read relative files create them first or fail identically on
both sides"**. That premise is FALSE for the rust arm, because 7 examples read their
OWN file by bare relative name — which a scratch CWD does not contain:

```
000__04c_text_processing_commands.sh   cat 000__04c_text_processing_commands.sh | head -5
id-cmdsub.sh  readonly-cmdsub.sh  realpath-cmdsub.sh
test_simple_function.sh  tty-cmdsub.sh  typeset-cmdsub.sh
```

Measured, running the example by ABSOLUTE path from a foreign CWD (exactly what
the gate would do):

```
$ cd /tmp/cwdtest2 && bash /home/llm/sh2loop/sh2perl/examples/000__04c_text_processing_commands.sh
=== Text Processing Commands ===
cat: 000__04c_text_processing_commands.sh: No such file or directory
First 5 lines of this file:
                                     <-- empty
grep: 000__04c_text_processing_commands.sh: No such file or directory
```

Note `rc=0` — bash does NOT fail, it prints the diagnostic and carries on with an
empty result. So this is not a loud breakage: it is a **silent** behaviour change
on both sides, and whether a cell goes red depends entirely on whether the
translation reproduces the empty capture.

(These 7 all still PASS under the fix in the worktree's own harness, because
`$f` is an absolute path and the renderer resolves it — but that is the c arm's
luck, not a property, and the 000__04c `cat` shows the corpus is not hermetic.)

## CORRECTION 2 — `046_cd..` observes the PARENT, so the scratch must be empty

`046_cd..sh` is:

```bash
cd ..
ls
```

It lists the **parent** of the CWD. `kill-session.sh` documents this exact class
(lines 65-72) and handles the `.eq_scratch_*` case by descending to
`$PWD/.sh2run/run`, so that `..` is a stable, cell-owned directory. That is necessary
but NOT sufficient: the parent must contain **nothing that differs between the two
runs**. My first attempt kept the compiled binary and the two captures beside the
run dir, and `ls ..` then reported a one-line difference on every trial:

```
got.out                     ref.out
prog.bin   <-- ls .. -->    prog.bin
prog.rs                     prog.rs
run                         ref.out
exit: 0                     run
exit: 0
```

`046_cd..` therefore **can never pass while the harness is visible to it**. The
working layout is two temp dirs: one holding `run/` (the only thing a cell may
observe) and a second, outside it, holding `prog.rs` / `prog.bin` / both captures.

Verified: with that layout `046_cd..` goes 0/3 -> 3/3 PASS and the full corpus
stays at 640 PASS / 0 MISMATCH.

## WHAT THIS ACTUALLY NEEDS (the decision is the core's)

The cross-talk and the self-read are in genuine tension:

- a stable, isolated CWD fixes 000__04c's shared-`file1.txt` clobber, but breaks
  the 7 self-readers;
- the corpus root fixes the self-readers but leaves 9 examples clobbering each
  other.

Neither CWD is correct for the whole corpus. Options, cheapest first:

1. **Give the scratch a stable copy of the example** (or a symlink to `$f`) so
   self-readers keep resolving, AND keep the scratch otherwise empty so CWD globs
   stay stable. This satisfies both constraints. Needs a decision on whether a
   symlink is enough for every self-reader (they all use `cat`/`grep` on the name).
2. **Serialize the colliding cells** — the collision is only between the 9
   examples that share `file1.txt`/`file2.txt`; running those in a single lane
   removes the race without touching the other 638.
3. **Rename per cell** by running each cell in a scratch seeded with the example,
   as (1).

I recommend (1): one `ln -s "$f" "$eq_scratch/$(basename "$f")"` (or a copy) is a
two-line change and preserves the hermetic-CWD property the c/perl arms already
rely on. I have NOT applied it, because choosing the corpus CWD semantics for a
backend arm is the core's call, not the rust worker's.

Verified regardless, in the worktree's own repro harness only:
`.gate/run_all.sh` and `.gate/faithful.sh` now give every cell its own scratch and
score both sides inside it. That harness is the rust worker's private tool — it
does not affect the real gate, and it is what produced the 6/6-pass measurement.
## OUTCOME: rejected: setup_backends.sh is not in the estree fix surface, and no rust backend arm exists (estree loop is the only worker) — this is a harness-side concern outside the estree core owner's scope.

