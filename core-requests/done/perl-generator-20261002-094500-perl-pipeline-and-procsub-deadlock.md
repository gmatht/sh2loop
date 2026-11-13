# A `a | b` pipeline is lowered to two SEQUENTIAL in-process calls — the child fills the pipe and the parent blocks forever

**Filed by:** the Perl GENERATOR worker
**When:** 2026-10-02 09:45
**Class:** shared-renderer control-flow bug (concurrency), not a missing lowering
**Gate effect:** 2 corpus examples **hang for the full 20 s gate timeout**
(`065_yes_head_while.sh`, `096_head_procsub.sh`). §3–§5 are a separate,
non-hanging class.

## The defect

`ir.rs` lowers a shell pipeline `A | B` as **two independent statements, in
the same Perl process**:

```perl
# 065_yes_head_while.sh:  yes Line:LINE | head -n100 | while read L; do … done
__sh_uu_run('yes', 'Line:LINE');  $main_exit_code = $CHILD_ERROR = $__sh_uu_rc;
__sh_uu_run('head', '-n', '100');  $main_exit_code = $CHILD_ERROR = $__sh_uu_rc;
while (do { my $__rd = <STDIN>; … }) { … }
```

`yes` is an **infinite** producer. Nothing reads the pipe while it runs, so it
fills the 64 KB pipe buffer and blocks in `write(2)` forever. `head` is never
reached. Same shape, same hang:

```perl
# 096_head_procsub.sh:  head <(while true; do echo .; sleep 1; done)
```

Proven directly — same generated program, unbounded producer isolated:

```console
$ tail -3 /tmp/v-065_yes_head_while.pl
__sh_uu_run('yes', 'Line:LINE'); $main_exit_code = $CHILD_ERROR = $__sh_uu_rc;
__sh_uu_run('head', '-n', '100'); $main_exit_code = $CHILD_ERROR = $__sh_uu_rc;
$ timeout 5 perl -M5.010 -e '…' /tmp/v-065_yes_head_while.pl ; echo $?
124
```

This is NOT specific to the UU-FFI arm. `__sh_uu_run`'s fork/exec fallback is
`system(@argv)`, and Perl's `system` does **not** redirect the child's stdout
to a pipe when the parent does not read one — the child inherits the parent's
*real* stdout, so a real pipeline is required. Both arms are wrong, and both
hang identically.

## Why it is a shared-core fix

The right lowering is a **real concurrent pipeline in one child** —
`exec { $pid } 'bash', '-c', $reconstructed_pipeline` — with the parent
reading the read-end. That is the same `bash -c` seam `emit_shell_cmd`
(ir.rs:5141) already uses for a single command, just with a `|` in the text
instead of a single util. `__sh_pipe_run` / `__sh_pipe_capture`
(ir.rs:10247 / 10262) already do exactly this and are the natural place to
route it: they call the in-process ABI and fall back to
`system('bash','-c', $cmd)` when it declines.

Two things must change:

1. **A pipeline must not be flattened into consecutive statements.** When
   `A | B` cannot be run in-process by one `__sh_pipe_run` call, it must be
   run as ONE `bash -c` with the pipeline intact.
2. **`__sh_pipe_unsupported_util` (ir.rs:10221) is an incomplete deny-list**
   and is one reason §3's builtins leak through. It currently whitelists
   `'perl|python3?|bc|find|strings|gunzip|gzip|zstd|bzip2|xz|tar|unzip|
   mapfile|readarray|ruby|node|php'`. `yes`, `head`, `env`, `comm`, `seq`,
   `readlink` are equally not in the pipeline `.so`. Invert it to an
   **allow-list** of utils the ABI is known to implement, so an unknown name
   cannot silently take a non-pipeline path.

I cannot fix this worker-side: it is a change to how `ir.rs` lowers a pipeline
statement, and the seam helpers live in the shared preamble constant.

---

## §3 — SHELL BUILTINS are routed into the coreutils FFI — `dot-source-lib.sh`

`pipeline_value_cmd` (ir.rs:10615) gates only on *shape*. It never consults
`is_shell_builtin` (ir.rs:11040), which the sibling `__sh_uu_run` decision at
ir.rs:7191 **does** consult for exactly this reason.

So `. ./lib_tmp.sh` becomes:

```perl
$main_exit_code = $CHILD_ERROR = __sh_pipe_run(q{'.' './lib_tmp.sh'}, "pipefail");
```

`__sh_pipe_run` gets `coreutils-ffi: unknown util '.'` on stderr, then falls
back to `system('bash','-c', …)` — a **child** shell. The sourced lib's
assignment lands in the child's scope and is discarded:

```
bash:  shared=secret
perl:  shared=
```

Same cause, two more examples: `parse-eval-multiline.sh`
(`unknown util 'eval'`), `typeset-cmdsub.sh` (`unknown util 'typeset'`).

**Ask:** `pipeline_value_cmd` must `return None` when the command's first
argv word `is_shell_builtin(...)`, routing to the `bash -c` path — which runs
in the *current* process scope, which is the whole point of a builtin.

---

## §4 — `grep -E` / `grep -Eo` / `grep -P` reach an in-process grep that implements neither — `grep_p.sh`, `070_gnuisms_thorough.sh`

`grep` IS in `%__SH_UU_OK` (ir.rs:10132), so these take the in-process arm.
The C grep there is a POSIX BRE subset:

```
coreutils-ffi: unsupported flag: -E
coreutils-ffi: unsupported flag: -Eo
coreutils-ffi: unsupported flag: -P
```

There is no capability query; the failure surfaces only as stderr text, which
the gate does not compare. The program continues and silently produces empty
output.

**Ask (preferred):** in `__sh_uu_run` / `__sh_pipe_run`, treat a `grep` argv
carrying `-E`/`-F`/`-P`/`-o` as "not in-process" and take the `system`/
`bash -c` path — GNU grep on the gate host, byte-identical to bash. One argv
predicate next to the existing `%__SH_UU_OK` lookup.

`070_gnuisms_thorough.sh` also needs `grep -P '\d+'` and `grep -Pc` (a
lookahead/atomic-group FQDN pattern the grep-pcre transform deliberately
refuses to translate). This handles all three because it declines to
reimplement them in-process at all.

---

## §5 — `process-substitution` producers are reordered past their consumer (latent)

`<(cmd)` is materialised with an **fd-redirect around the producer's body**:

```perl
open(my $__sh2_rfh0, '>&', \*STDOUT); close(STDOUT);
open(STDOUT, '>', $__ps_tmp0);
print "one\n";                       # the producer's body
select($__sh2_rsel0); open(STDOUT,'>&',$__sh2_rfh0);   # restore
```

A `print` is a **buffered Perl operation**. The `select` is emitted
*lexically after* it, but Perl flushes at the end of the enclosing `do { }` /
block scope, not at statement boundaries, so the consumer — emitted in a
**later statement** — can run before the producer's bytes land.

Measured status, to be precise: `process-substitution.sh` under a quiet box is
**correct** (stdout matches bash exactly, exit 1). It was reported as exit 124
in my first pass only because the box was at loadavg 23 with a concurrent gate
starving it; `070_cmp_basic.sh` likewise passes on a re-run. So this is a
**latent** ordering hazard, not the hang. I flag it because the same
fd-redirect shape appears in `echo > file`, and the fix is the one Perl wants:
an explicit flush where the redirect is closed, not a reliance on scope-exit
flushing.

**Ask (low priority):** emit an explicit flush at the point the redirect is
closed.

---

## A correction to an earlier claim of mine

I first wrote that the `use English` import and the `__SH_UU_OK` preamble were
being dropped because the gating scans run before the body is appended to
`out` (ir.rs:1295 / 1423). **That was wrong**, and I retract it. Measured on
the current binary:

```console
$ for n in 065_yes_head_while 096_head_procsub process-substitution; do … done
065_yes_head_while:    english=0 open3=0 sub_sh_uu_run=1 bodycalls=2
096_head_procsub:      english=0 open3=0 sub_sh_uu_run=1 bodycalls=1
process-substitution:  english=1 open3=0 sub_sh_uu_run=1 bodycalls=0
$ perl -M5.010 -c /tmp/v-065_yes_head_while.pl   # syntax OK
$ perl -M5.010 -c /tmp/v-096_head_procsub.pl    # syntax OK
$ perl -M5.010 -c /tmp/v-process-substitution.pl # syntax OK
```

All three compile. `sub __sh_uu_run` is present in all three, and the
`English` import is gated correctly on `$INPUT_RECORD_SEPARATOR` (absent in
these two programs, so correctly not imported). The missing import in an
earlier `process-substitution.pl` artifact was a stale file from a different
run, not the render. The scans are not the problem; the pipeline lowering is.

## Verification

All reproductions use the gate's own helper:

```console
$ PG_ONLY=<list> bash harness/pg-classify.sh /tmp/pg
```

Specific checks, each reproducing on the current binary:

```console
$ diff <(bash sh2perl/examples/dot-source-lib.sh) \
       <(perl -M5.010 -e '$0=shift; do shift' <gen>)
< shared=secret
> shared=

$ timeout 5 perl -M5.010 -e '…' /tmp/v-065_yes_head_while.pl ; echo $?
124

$ grep -c 'use English' /tmp/v-065_yes_head_while.pl
0                       # correct — NOT a bug, see the correction above
```

I have deliberately NOT touched `ir.rs`. My own file's fixes land separately
and are independent of every item above.

## OUTCOME: rejected: Perl pipeline lowering — perl-only surface, out of scope.
