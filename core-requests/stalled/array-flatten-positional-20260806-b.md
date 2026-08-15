> RESEND (re-filing). The 21:07/23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# array-flatten + "$@" in exec args (t65/t67 ladder probes)

Probe-verified (bash vs estree mismatch):
- t65: `printf "<%s>\n" "${arr[@]}"` → bash 3 lines, estree 1 line ("<a b c>").
- t67: `set -- alpha beta; printf "<%s>\n" "$@"` → bash 2 lines, estree 1
  line ("<alpha beta>").

## NEED

`${arr[@]}` / `${arr[*]}` and `"$@"` in exec-arg position must expand into
SEPARATE args (bash arg-count semantics). The general path already works
for `${arr[@]}` (param(slice) returns arrayItems → exec flattens) — only
the printf/echo INLINE paths corrupt it; `"$@"` is broken in both paths
(quoted form lowers to the joined scalar).

## WHY

1. `${arr[@]}` (no offset) → A1 `param("slice", name, "@", "")` — the
   runner returns `this.arrayItems(name)` (an ARRAY). The printf/echo
   inline paths (try_native_printf exclusion, echo_arg_to_estree
   bare-keep set, echo_join_args flat set) treat it as scalar → template
   interpolation / join corruption.
2. Quoted `"$@"` → A1 `getVar("@")` — the runner returns the joined
   positional string; bash requires separate args. Unquoted `$@` already
   lowers to `listVar("@")` (the correct array form, exec-flattened) —
   the QUOTED form must match. (Quoted `"$*"` stays getVar — bash joins
   it into a single arg — the current behavior is correct for `$*`.)

## MINIMAL-CORE-CHANGE

1. Add `param("slice", name, "@"|"*", …)` (the a-arg, not the name
   suffix) to the array-valued detection at the three inline sites
   (same set as split/captureWords/listVar).
2. partIR's `case part.Var != ""`: for name "@" emit
   `call("listVar", …)` instead of getVar (mirroring the Word::Variable
   path at 5012). The inline exclusions already cover listVar, and the
   general exec path flattens it.

## FAILING-CASE

```sh
arr=(a b c)
printf "<%s>\n" "${arr[@]}"     # bash: 3 lines; estree: 1
printf "<%s>\n" "${arr[*]}"     # bash: 1 line "<a b c>"; must stay 1
set -- alpha beta
printf "<%s>\n" "$@"            # bash: 2 lines; estree: 1
```

## GATE

`cargo build --bin debashc && cargo test --lib`; the probes above vs
bash; `./fail` + `./fail-estree` (corpus-side: `"$@"` corpus uses are
for-loops and echo — output-invisible; expect zero corpus change).
