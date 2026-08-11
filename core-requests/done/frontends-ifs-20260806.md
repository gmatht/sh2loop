# frontends: IFS semantics — custom-separator split and read

## NEED

IFS-aware field splitting: `IFS=, read a b c` and `IFS=, for w in $x`
must split on the IFS value, not just whitespace. The runner's split()
is whitespace-only; the `read` builtin's field splitting and the
exec-arg splitting ignore a custom IFS. The posix/fish/zsh frontends'
ladders need it (read with multiple vars, comma-separated parsing).

## WHY

The A1 `split` marker is the field-split contract; its runtime behavior
is whitespace-fixed. Real POSIX sh uses IFS for reads and expansions —
the frontends can't express `IFS=, read a b c` (the read's fields) at
all.

## MINIMAL-CORE-CHANGE

- The runtime's split/read honor `this.vars.get('IFS')` when set (the
  `${x[*]}` join already does — line 492); a custom IFS is a string of
  separator chars, IFS-space being the whitespace-collapsing default.
- The split marker's runtime: split on the IFS characters.
- Document the IFS rules (the shell's field-splitting spec) in the
  contract.

## FAILING-CASE

```sh
IFS=, read a b c <<< "1,2,3"
echo "$a $b $c"
```

## GATE

`cargo test --lib`; the probe above executes correctly; corpus unchanged
(default IFS is whitespace — the existing behavior).
