# c: `echo_return` lift does not descend into `case` PATTERNS — a `$(fn)` capture mis-lowers

## NEED

The shared `echo_return` transform (`sh2perl/src/transforms/echo_return.rs`)
must descend into a `case` clause's PATTERNS, so that a whole-pattern
command substitution of a program-defined shell function is lifted to the
value-returning `fnValue` convention the way the identical construct in
every other word position already is.

## WHY

A `$(fn args…)` whose command word names a program-defined shell function
cannot be lowered by fork/exec: the child `execvp`s the FUNCTION NAME,
there is no such binary, the child fails and the capture comes back EMPTY.
The c renderer's own `capture_call` documents this and has an
`fnValue` arm for it, but that arm is additionally gated on
`self.functions`, which the c renderer never populates — so in practice
the ONLY working path for `$(fn)` is this frontend lift. Where the lift
does not fire, the capture silently lowers to the empty-output fork/exec
form.

Consequence today: a `case` pattern built from a command substitution of a
shell function compares against the EMPTY string, so the clause never
matches. This is not hypothetical — the corpus already contains the exact
shape (`sh2perl/examples/parse-redirect-in-case-pattern.sh`), and it is
INVISIBLE there only because that particular function's output is also the
empty string, so the wrong lowering happens to agree with bash on stdout.

Measured: the C gate renders `fnmatch(_sh_pipeline(_sp0, 1, &_pipe0), …)`
with `_a0_0[] = {"f", 0}` for the failing case below, and the script's own
function `f` is not even emitted into the C output (the lift that normally
registers and emits it never sees the call).

## MINIMAL-CORE-CHANGE

Extend `echo_return`'s statement walk so it also visits the `patterns` of
an `IrStmt::Case` clause (the same way it already visits the bodies), and
lifts a `$(...)`/`` `...` `` occupying a WHOLE pattern to
`fnValue(name, args)`. No new node, no serde change, no schema change —
the node it needs (`Call("fnValue", …)`) already exists and is already
consumed by every backend. c's renderer needs no change once the lift
fires: `case_subst_value` → `value_c` → the `fnValue` arm then emits the
in-process `_sh_capture_fn` dispatch.

(Alternative, if the lift is deliberately word-position-only: populate the
c renderer's `functions` set and let `capture_call`'s existing, currently
dead `fnValue` arm handle the pattern. I did NOT do that here because it
would activate 16 other `self.functions` gates in c_backend.rs that have
never run, and I could not order that change against the corpus in the
time available. If you prefer that direction, say so and I will scope it.)

## FAILING-CASE

```sh
#!/bin/bash
f() { echo got; }
y=got
case "$y" in
    "$(f)") echo MATCH ;;
    *) echo NOMATCH ;;
esac
```

- `bash` prints `MATCH`.
- the c render of this program prints `NOMATCH` (the pattern lowered to an
  empty capture; `execvp("f")` fails).

The corpus cell that pins the same shape with an empty-output function
(and so currently passes for the wrong reason) is
`sh2perl/examples/parse-redirect-in-case-pattern.sh`:

```sh
_docker_to_extglob() { echo "$1"; }
case "${words[$counter]}" in
    $(_docker_to_extglob "$subcommands") ) echo match ;;
esac
```

Its rendered C contains `_sh_pipeline(_sp0, 1, &_pipe0)` with
`_a0_0[] = {"_docker_to_extglob", …}` and no `_docker_to_extglob`
definition — the same mis-lowering, masked by an empty expected value.

## OUTCOME: implemented

Landed as `echo_return` Pass 4 (`hoist_case_pattern_captures` +
`lift_pattern_capture`), commit sh2perl 0e9cf7ecb. A `$(f)`/backtick occupying
a WHOLE `case` pattern of an eligible echo-return callee is hoisted into a
preceding `__sh2_casepat_N=$(f)` capture (which the normal capture path lifts
to `fnValue`) and the pattern is pointed at the temp, so the pattern is no
longer opaque text carrying an invisible call. Non-eligible callees and mixed
patterns are left exactly as-is.

Verified on the filing's failing case: `f() { echo got; }; y=got; case "$y"
in "$(f)") echo MATCH ;; *) echo NOMATCH ;; esac` now lowers to
`__sh2_casepat_0 = fnValue("f", [])` + `patterns: ["\"$__sh2_casepat_0\""]`
and prints `MATCH` (estree runner). No new node, no serde change.
