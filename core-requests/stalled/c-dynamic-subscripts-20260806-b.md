> RESEND (re-filing). The 21:07/23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# c-frontend: dynamic array/string subscripts (s[k], arr[k], p+n with a variable)

## NEED

The A1 subscript forms must carry NON-LITERAL keys/offsets. The C
frontend's pointer lowerings only fold LITERAL indices today:
`s[0]` -> 1-char slice, `arr[1]` -> arrayIndex, `p+1` -> base+1 folded.
Dynamic indexing — `s[k]`, `arr[k]`, `p + n` with a VARIABLE — is the
common C pattern (`for (i = 0; i < n; i++) buf[i]`) and currently
refuses/falls back.

## WHY

The core ALREADY lowers dynamic indices: `${arr[$i]}` -> the baked-name
getVar path (`param("", "arr[$i]")` / getVar("arr[$i]")), where the
runner's evalArith resolves the `$i` text. The contract does not
DOCUMENT or guarantee the non-literal subscript for the arrayIndex /
param-slice shapes the frontends emit, so the C frontend cannot rely on
it.

## MINIMAL-CORE-CHANGE

Document and verify the canonical dynamic-subscript shapes:
- `arrayIndex(name, key)` where key is an EXPRESSION (getVar/Arith) —
  the runner's `evalArith(String(key))` must resolve variable text; the
  emitter renders the key arg as-is.
- `param("slice", name, off, len)` with non-literal off/len (a getVar).
- A structural-gate note: the subscript/offset args are no longer
  Str-only; the deserializer already accepts any expr.

## FAILING-CASE

```c
char buf[4] = "abcd";
int k = 1;
printf("%c\n", buf[k]);     /* dynamic index -> refused today */
int a[3] = {10, 20, 30};
int i = 1;
printf("%d\n", a[i]);       /* same */
```

## GATE

`cargo test --lib`; the C frontend emits the dynamic shapes and they
execute (gcc == estree); corpus unchanged (the baked-name path already
handles ${arr[$i]}).
