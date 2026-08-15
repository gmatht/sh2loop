# core: ir_to_perl infinite-loops on typeset-cmdsub.sh (the perl-generator hang class)

## NEED

`debashc file --perl examples/typeset-cmdsub.sh` must terminate. Today it
spins at 100% CPU forever (verified: 68 syscalls total, zero I/O, pure
user-space — an internal infinite loop in the core's legacy ir_to_perl).
`--shir` and `--estree` on the same file both return 0 — the hang is
perl-rendering-only. Same family as the earlier `009_arrays.sh` hang (66
min at 100% CPU).

## WHY

The hang wedges every consumer that reproduces it: the remote rust loop's
pi spawned `debashc typeset-cmdsub.sh` and stalled for 50 minutes on the
unclosed pipe (twice now). The file is in the corpus's failing set
("debashc failed to generate code" class) — the rust loop cannot work
its own queue while this hangs its reproductions. A bounded failure
(timeout/error) would be fixable; an infinite loop is not.

## MINIMAL-CORE-CHANGE

Find and break the infinite loop in the perl generation path for the
typeset-cmdsub construct (typeset/declare + command substitution —
`typeset -i n=42` and below). The loop is likely a state machine that
fails to advance on some node (a `while` without a cursor advance, or a
recursive generator without a base case). Reference: the loop's own
`timeout` guard should turn it into a bounded failure even before the
root cause is found — but the root fix is the advance/termination.

## FAILING-CASE

```sh
# typeset-cmdsub.sh (corpus)
unset n
typeset -i n=42
echo "After 'typeset -i n=42': n='$n'"
# ... (the file continues; bisect shows the hang is in the typeset/cmdsub region)
```
Reproduce: `timeout 15 sh2perl/target/debug/debashc file --perl sh2perl/examples/typeset-cmdsub.sh` (rc=124).

## GATE

`timeout 15 debashc file --perl sh2perl/examples/typeset-cmdsub.sh` exits
(any rc, not 124); the file joins the perl corpus; the corpus's other
perl-gen hangs (009_arrays.sh) are re-checked for the same class.

## NOTE

The estree worker is decoupled from perl work (the rust loop owns the
perl backend); this request documents the hang precisely so the rust
loop can implement it — or the mediation can route it. Either way the
bug is on record with a reproducible case.
