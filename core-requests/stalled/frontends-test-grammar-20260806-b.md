> RESEND (re-filing). The 21:07/23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# frontends: the test-expression STRING grammar as a documented contract

## NEED

The `test("...")` string is the frontends' condition channel — py-sh-go
emits `test("$x -gt 1")`, c-sh-go emits `test("$a -eq $b -a ...")`, all
frontends lower their languages' conditions into it. The grammar
(operators: -eq/-ne/-lt/-le/-gt/-ge/-n/-z/-f/-d, -a/-o, !, glob `==`,
regex `=~`, the $var expansion) is currently an IMPLICIT runtime
contract — every frontend discovers it by trial (the c-sh-go testExpr
had to find -gt/-a/-o empirically). It must be a documented,
machine-readable spec (like harness/sh2-namespace.json), so frontends
derive rather than guess.

## WHY

Each new frontend re-discovers the grammar and gets the edges wrong
(the c-sh-go `&&` → -a fix, the `=`-vs-`==` comparison trap). A spec
prevents the whole class; an extension (`=~` regex for py/perl
string conditions) would unblock richer conditionals.

## MINIMAL-CORE-CHANGE

- Publish the grammar as data (a `test-grammar.json` or a section of
  sh2-namespace.json): operators, arity, precedence, the expansion
  rules.
- Document/guarantee `=~` (regex) and glob `==` in the grammar (the
  runner already parses them — BIN_OPS includes `=~`).
- Frontends derive their condition lowering from the spec.

## FAILING-CASE

```python
s = "hello"
if re.search(r"^h", s):   # py condition -> needs =~ semantics
    print("star")
```

## GATE

`cargo test --lib`; the spec exists; a frontend lowers a condition
purely from the spec without runtime trial-and-error; corpus unchanged.
