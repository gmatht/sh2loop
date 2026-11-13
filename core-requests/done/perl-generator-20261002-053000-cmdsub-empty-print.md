# `echo \`cmd\`` lowers to a bareword — the command substitution's VALUE is never captured

**Filed by:** the Perl generator worker
**Scope:** shared core (`src/ir.rs` — `param_text_to_perl` / the pipeline
lowering). NOT `perl_generator_fixed.rs`; this cannot be fixed in the
backend post-pass.

## The bug

A command substitution used as a command's ARGUMENT renders with an empty
argument list. The capture is not performed at all — not merely captured
wrongly — so the substituted output is silently dropped from stdout.

Minimal repro (`008_simple_backup.sh`):

```sh
echo "Hello, World!"
ls -1 | grep -v a.txt
echo `ls | grep -v a.txt`     # <- the subject
```

bash stdout:

```
Hello, World!
b.txt
sub1
sub2
b.txt sub1 sub2      <- last line, the substitution
```

generated `t.pl` (the capture is a complete no-op; only the newline survives):

```perl
$main_exit_code = $CHILD_ERROR = __sh_pipe_run(q{'ls' '-1' | 'grep' '-v' 'a.txt'}, "pipefail");
print('', "\n");
```

The two defects visible on that one line are separable, and **only the first
is the core's**:

1. `print('', "\n")` — the argument list is empty. This is the bug above.
   The pipeline immediately above was captured correctly by
   `__sh_pipe_run`, so the machinery exists; this lowering simply does not
   call it.
2. Trailing-newline handling: even once the value is captured, bash's
   `echo \`cmd\`` word-splits the captured text on `$IFS` and the result is
   printed as `b.txt sub1 sub2` (single spaces, no embedded newlines). A
   naive `print($capture, "\n")` would emit the raw `b.txt\nsub1\nsub2`.
   The lowering needs the `join(' ', split(/\s+/, …))` shape the same
   generator already uses for `for … in "\`cmd\`"` (see Fix 10/11 in
   `perl_generator_fixed.rs`) — so once the capture exists, the split is a
   backend detail and only the capture itself needs core support.

## Evidence

- Corpus: `008_simple_backup.sh` (diff `-1 +1`, last line).
- The same empty-argument render appears wherever a `$(…)`/`` `…` `` is an
  argument rather than a whole command; `harness/pg-one.sh` reproduces.

## What the core should decide

Whether the capture belongs in the shared lowering (so every backend gets a
value channel for "substitution as argument") or whether the argument slot
is expected to render as an expression the backend can consume. Today the
`$(…)` appears in the shIR but is dropped on the way to the argument list,
which suggests the argument-slot path does not consult the substitution at
all — the `Cmd`/argument-list builder, not the substitution evaluator.

## Not fixed here

Deliberately left to the core owner: `src/ir.rs`, `src/shir.rs`,
`src/estree.rs`, `src/parser/`. The Perl generator worker did not touch them.
## OUTCOME: implemented
Root cause was NOT the argument-slot builder: the capture body arrives as the
STATEMENT variant `IrStmt::Pipeline`, and `stmts_to_shell_cmd` had no arm for it,
so it returned None and the value was never reconstructed. The Arrow-wrapped
`pipeline` Call form was already handled (`expr_to_cmd` -> `pipeline_call_to_cmd`);
only the statement form was missing. Fixed by adding the arm, reusing a new shared
`stages_to_shell_cmd` helper extracted from `pipeline_call_to_cmd` (one
implementation of the refuse-rather-than-drop-a-stage invariant).
Verified: 008_simple_backup.sh MISMATCH -> MATCH; ./fail-estree ESTREE 557/557
unchanged, PERL 507 -> 508; regression test fails pre-fix (renders the reported
`print('', "\n")`) and passes post-fix. Commit 8dce38e3d.
