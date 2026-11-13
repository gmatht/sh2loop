# Core request: `$(( … ))` with a `${…}` operand inside a plain assignment is DROPPED

Filed 2026-10-14 by the perl-gate session (worktree `.pir-perl-fix`,
branch `pir-sqfix`).

## Symptom

```
$ cat t.sh
result=$(( ${var:-0} + ${array[${index:-0}]:-0} ))
echo "r=$result"

$ bash t.sh
r=0

$ otranspilerl-cli --target pl t.sh
#!/usr/bin/env perl
use strict;
use warnings;
my $main_exit_code = 0;
our $CHILD_ERROR = 0;
my $result;

print("r=" . ($result), "\n");  # line 2      <-- the ASSIGNMENT is gone
```

The assignment statement does not appear in the emitted Perl at all, so
`$result` is undef and the program prints an empty value where bash
prints `0`.

It is **not** specific to `eval`: the same drop happens for the bare
statement, and it is what makes `063_12_complex_eval` fail (it prints the
raw `$(( ${var:-0} + ${array[${index:-0}]:-0} ))` text).

## Where

The statement DOES reach the A1 — `--shir` shows an
`{"type":"Assign","targets":[{"var":"result",…}],"expr":{"type":"Arith",…}}`
— so this is not an ingress loss. Compare the working shape:

```
$ echo 'result=$(( 1 + 2 ))' | otranspilerl-cli --target pl -
$result = int((1 + 2));            # correct
```

So the difference is the `${…}` **operands inside the arithmetic**. My
reading is that the arithmetic-substitution parser refuses (or
mis-scans) an expansion between the `$((` and `))` when the expansion
itself contains `[`/`$` nesting (`${array[${index:-0}]:-0}` has a `$`
inside the subscript and a `:-0` default), and the enclosing assignment
is then dropped rather than degraded.

`perl_generator_fixed.rs` (the perl GENERATOR pre-pass) documents the
same class from its side: `is_inlinable_stmt`'s comment names
`eval "result=$(( ${var:-0} + ${array[${index:-0}]:-0} ))"` as a payload
whose rendered Perl "does not compile: the arithmetic expansion is
emitted verbatim (`${array[${index:_0}]:_0}`) into a program that has
only `my %array`". That guard makes the EVAL path *refuse* — correct, and
it is why the eval path at least keeps a visible wrong value. The bare
assignment has no such guard, so it is dropped silently.

## Ask

Either (a) parse the nested-operand arithmetic expansion correctly, or
(b) if the shape is genuinely unhandleable, emit a LOUD refusal (a `die`
with the shape named) instead of dropping the statement — a dropped
assignment is the worst failure mode, because stdout looks like a clean
run that lost a value.

## Corpus

`sh2perl/examples/063_12_complex_eval.sh` is the direct gate.
`parse-dollar-in-arithmetic.sh` is the neighbouring shape (a `$1`
positional inside `$(( … ))`) and fails for a related reason (bash's own
error path is not reproduced).

## OUTCOME: implemented (re-verified this round)
The nested-operand arithmetic expansion is no longer dropped. The filing's exact
repro:

    result=$(( ${var:-0} + ${array[${index:-0}]:-0} ))
    echo "r=$result"

renders the assignment in the emitted Perl and prints `r=0`, matching bash. The
perl GENERATOR's `is_inlinable_stmt` refusal also no longer fires for the bare
shape. No new loud-refusal path was needed: the expansion now lowers.

The neighbouring `parse-dollar-in-arithmetic.sh` behaviour (a `$1` positional
inside `$(( ))`) is unchanged and was not part of this request.
