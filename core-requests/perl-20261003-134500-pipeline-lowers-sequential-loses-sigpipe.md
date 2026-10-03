# perl: a pipeline lowers to SEQUENTIAL `__sh_uu_run` calls, so an unbounded producer never gets SIGPIPE — 75 GB per gate run

## NEED

`sh2perl/src/ir.rs` lowers a shell pipeline `a | b` into **two independent
statements** rather than one pipe. That destroys the only mechanism bash
uses to terminate an unbounded producer, so the producer writes until it is
killed. Measured on `sh2perl/examples/065_yes_head_while.sh`
(`yes Line:LINE | head -n100 | while read L; do ...`):

```
$ timeout 4 perl ... 065_yes_head_while.sh gen.pl | head -c 300000000 | wc -c
300000000      # 300 MB in 4 seconds, still going
```

Under the gate (`timeout 20`) that is **~75 GB of stdout per example**, and
`sh2-cap: perl truncated at 1048576 bytes (stream was 82898401950)` is in
`loop-estree.log` **97 times** (counted 13:35; it grows every iteration). The estree loop shows `rchar` 715 GB /
`write_bytes` 17.6 GB. This is the single largest I/O consumer on the box
and it starves every other backend gate behind it.

The emitted Perl (`--target pl`, line 174-175):

```perl
__sh_uu_run('yes', 'Line:LINE'); $main_exit_code = $CHILD_ERROR = $__sh_uu_rc;  # line 3
__sh_uu_run('head', '-n', '100'); $main_exit_code = $CHILD_ERROR = $__sh_uu_rc;
while (do { my $__rd = <STDIN>; ... }) { ... }
```

Two consequences, both measured:

- **Wrong output.** bash prints 100 lines, `Line:1` .. `Line:100`. The
  translation prints endless `Line:LINE` — the producer's literal argument,
  because nothing pipes it into `head`'s reader.
- **Unbounded I/O.** `head` never reads the producer, so it never closes the
  pipe, so `yes` never takes SIGPIPE.

## WHY

The lowering is not missing infrastructure — the pipeline runtime is
already emitted in the same preamble (`__sh_pipe_run`,
`__sh_pipe_load`, `uu_pipeline_run_str`, `harness`-provided
`libcoreutils_ffi.so`), and `__sh_pipe_unsupported_util` explicitly does
**not** exclude `yes` (its list is perl/python3/bc/find/strings/gunzip/
gzip/zstd/bzip2/xz/tar/unzip/mapfile/readarray/ruby/node/php). So the pipe
path was reachable and was simply **not selected** for this shape.

The C backend lowers the same source correctly — `_sh_addraw("|")` sits
between the stages — so this is **perl-specific**, not a contract-node gap.

Two dead ends I ruled out by measurement, so they are not worth chasing:

- **Not** `__sh_uu_capture`'s temp file. `yes` is not in
  `%__SH_UU_OK` (`cat wc ls sort sed awk grep date sha256sum uname basename
  dirname cp`), so `__sh_uu_run` takes the `system(@argv)` arm (line 44-52)
  and writes to inherited STDOUT. The `/tmp/sh2_uu_$$.cap` path is never
  entered for this example.
- **Not** a bad example class. Of the 9 corpus examples that use `yes`,
  only this one misbehaves; the other 8 emit 0-342 bytes and exit.
  `065_yes_head_while` is also a **deliberate** hang-robustness test
  (`BAD_EXAMPLES.md`: "a buffering translator must stream and terminate, not
  buffer and hang. The gate's 15s timeout is the assertion"), so the fix
  must make it terminate *correctly*, not exempt it.

## MINIMAL-CORE-CHANGE

Make the perl pipeline path engage for a linear `a | b` of static external
commands, instead of emitting two sequential `__sh_uu_run` calls. The
preamble already has `__sh_pipe_run($cmd, $opts)`; the fix is in the
**selection** at the pipeline lowering, not in the runtime.

Scope: `sh2perl/src/ir.rs`, the perl pipeline lowering only. It must not
change the `qx{}`/capture semantics, and must not regress the shapes that
currently pass (the perl gate is 306/649 render-OK today).

If a linear pipe of externals cannot be lowered natively for some reason,
the **minimum acceptable** change is to keep the shell for this shape —
`__sh_qx_run` already does `open('-|', 'bash', '-c', $cmd)`, and a real
`bash -c` pipeline restores SIGPIPE, terminates `yes`, and produces the
correct 100 lines. Either way the producer must be able to take SIGPIPE.

## FAILING-CASE

```
examples/065_yes_head_while.sh
```

bash reference: 100 lines, `Line:1`..`Line:100`.
Current `--target pl`: unbounded `Line:LINE`, ~75 GB before `timeout 20`.

## VALIDATION

1. `otranspilerl-cli --target pl examples/065_yes_head_while.sh`, then run
   it with a hard byte cap and a 15 s timeout. It must **terminate on its
   own**, print exactly 100 lines matching bash byte-for-byte, and write
   well under 1 MiB.
2. `./fail` for perl: the `065_yes_head_while` FAIL must clear, and the
   render-OK count must not drop below 306.
3. Regression-check the other 8 `yes` examples — they must stay at their
   current byte counts and verdicts.
4. `sh2-cap: perl truncated` must no longer appear in `loop-estree.log`
   with a multi-GB `stream was` figure.

## NOTE — already filed three times, never actioned

This is the **fourth** request for the same example. The prior three are in
`core-requests/stalled/`, and each describes a *different* (and less
precise) mechanism, which is likely why none was picked up:

- `perl-generator-20260929-053500.md:119` — "`065_yes_head_while` loses the
  producer and loops on inherited STDIN"
- `perl-generator-20261002-090855-...-cfix-shadow-core.md:136` — lists it
  among "perl exit 124" timeouts
- `perl-generator-20261002-094500-perl-pipeline-and-procsub-deadlock.md:16`
  — describes it as a pipeline/procsub deadlock

The diagnosis above supersedes those: it is a **pipeline-selection** defect
in the perl lowering (SIGPIPE is lost), not an STDIN-inheritance loop and
not a deadlock. Filed with measurements so it is actionable as-is.