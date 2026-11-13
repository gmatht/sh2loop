# core-request: a `${v:-...}` default keeps its operand as an OPAQUE literal string

**From:** perl-generator worker
**Scope of the request:** the core (parser/IR lowering). NOT fixable in
`sh2perl/src/perl_generator_fixed.rs` — see "Why no backend can fix this".

## Symptom

Two corpus examples generate Perl that **does not compile at all**, so they
emit 0 bytes and every other construct in the file is silently lost:

```
$ perl -c gen.pl
Bareword found where operator expected (Missing operator before "echo"?) at gen.pl line 13, near "$(echo"
syntax error at gen.pl line 13, near "$(echo "
gen.pl had compilation errors.
```

Offending generated line (from `063_04_complex_parameter_expansion.sh`):

```perl
print(((defined($var) && length($var)) ? $var
       : substr($default, -${fallback, -$(echo "computed")})), "\n");
```

## Minimal repro

```bash
echo '${var:-${default:-${fallback:-$(echo "computed")}}}'
```

## Root cause (verified in the IR dump, `PG_DUMP_IR=1`)

The IR does **not** lower the nested command substitution. It arrives as a
single flat `Str` node whose VALUE is the original source text, escapes and
all:

```rust
Call { func: "param", args: [
    Str(":-", DoubleQuoted),
    Str("var", DoubleQuoted),
    Str("${default:-${fallback:-$(echo \"computed\")}}", DoubleQuoted),  // <-- opaque
]}
```

So the whole `${default:-${fallback:-$(echo computed)}}` tail — including the
`$(...)` — is an inert string by the time any backend sees it.

A `Str` is not a bare `Str` in this IR though: the renderer (rightly) treats a
`Str` that still contains `$(`/`${` as *un-lowered source* and splices it into
the output verbatim. That splice is what leaks the raw `$(` into Perl, where
Perl parses `$(` as the GID special variable and dies.

Two distinct core defects, worth separating:

1. **A command substitution nested inside a parameter-expansion default is not
   lowered.** Compare the sibling case, which IS lowered correctly — a `$(...)`
   at the top level of an argument becomes a real `Call { func: "capture" }`.
   Inside `${v:-...}` it stays text. That is the actual gap.

2. **A `Str` that still contains live expansion syntax is spliced into the
   target language verbatim.** That is a latent footgun for every backend: an
   un-lowered operand is indistinguishable from an opaque literal, so any
   construct the lowering misses turns into a syntax error in the target
   rather than a diagnosable "unsupported" verdict.

## Why no backend can fix this

The information is already destroyed. By the time a renderer runs, the operand
is the single string `${default:-${fallback:-$(echo "computed")}}`. A backend
*could* re-lex that string by hand, but that means writing a second shell
parser inside every backend, and it would be unsound for any operand the core
deliberately keeps opaque (a literal `${` that the user escaped, a string built
by `printf` with no expansions at all, a here-doc body). Re-lexing is exactly
the kind of guess that turns "one wrong line" into "silently wrong semantics".

Per the marketplace rule this is core-owned: it is a shared lowering, it
affects every backend equally, and the fix belongs in one place.

## Suggested shape of the fix

Lower the expansion before it becomes a `Str`:

- In the parameter-expansion lowering, re-parse the default operand with the
  same expansion parser used for the rest of the word, so a nested `$(...)`,
  backtick, or `${...}` becomes real IR nodes and an operand with no live
  expansion stays a plain `Str`.
- Add a core test pinning the round trip for `${a:-${b:-$(cmd)}}`: the IR must
  contain a `Call { func: "capture" }` (not text) for the `$(cmd)`.
- Consider an explicit `Str { expanded: true }`-style marker, or an
  `Unsupported` verdict, so an un-lowered operand can never be silently
  spliced as a literal. Failing loudly is strictly better than a syntax error
  in the target.

---

# Gap 2 (ADDED 23:24): `${v/pat/rep}` is a SILENT NO-OP in the renderer

**Status: a core-request of its own — the fix is three lines in `ir.rs`, and
it is a much bigger win than Gap 1.** Filed together because both are
`param_value`/`render_param` defects, but they are independent: this one needs
no parser work at all and can be landed today.

## Symptom

Every single-slash pattern substitution in the corpus is a no-op. It fails
silently — correct exit code, no warning, just the wrong text:

```
$ s=abc:def:ghi; echo "${s/abc/XYZ}"     # bash: XYZ:def:ghi
front=abc:def:ghi                        # perl: unchanged
```

## Root cause

`shir::ast_to_ir` hands the operands over BARE — `param("/", "s", Str("abc"),
Str("XYZ"))`, confirmed by IR dump. The quotes are added afterwards, by
`render_param`, which builds `val`/`repl` through `param_value` **before**
dispatching on the op:

```rust
let val  = args.get(2).map(param_value).unwrap_or_default();   // ir.rs:4277
let repl = args.get(3).map(param_value).unwrap_or_default();   // ir.rs:4281
match op.as_str() {
    "/" => format!("(({} =~ s/{}/{}/r))", var, glob_to_regex(&val), ...),
    ...
}
```

and `param_value` ends in `render_str_literal(t, &StrStyle::DoubleQuoted)`
(ir.rs:4217) — hardcoded `DoubleQuoted`, the node's own `StrStyle` discarded.
`render_str_literal`'s job is to emit a *Perl string literal*, so the operand
comes back as `"abc"` and is spliced into a **regex** position:

```perl
$s =~ s/"abc"/"XYZ"/r
```

Perl compiles that as "six characters `"abc"`", which never occur in the
subject. Match fails, `s///r` returns the subject unchanged. No warning.

## Two secondary defects in the same arm

1. **The `"/"` arm at ir.rs:4434 is DEAD CODE.** It is shadowed by the later
   `"\//" | "/"` arm at ir.rs:4440, which matches the same op. The dead arm
   uses `val` (the pre-rendered string literal) as its pattern and
   `repl.trim_matches('\\')`; the live one re-reads both operands with
   `call_arg_str` and runs the pattern through `glob_to_regex`. The live arm
   is the correct one, so this is latent rather than active — but it is a trap
   for the next reader, and it is why the bug has been hard to see.

2. **`param_value` ignores `StrStyle` on its `Str` arm.** A backend therefore
   cannot even ask for a raw operand: I tried marking the operand
   `StrStyle::Raw` in the generator (the IR's existing spelling for "this text
   is already code") and it had **zero** effect on the `/` arm, because
   `param_value` throws the style away. I reverted that change rather than land
   dead code. `render_str_literal` does honour `StrStyle::Raw` (ir.rs:8954), so
   the style is being dropped one layer too early.

## Suggested fix (core, `ir.rs` only — no parser change)

Make the substitution arms read their operands the way the `#`/`%` arms do,
i.e. with `call_arg_str` (raw text) instead of the `param_value` string
literal, and let `glob_to_regex` do the escaping:

```rust
"/" | "//" => {
    let pat = args.get(2).and_then(call_arg_str).unwrap_or_default();
    let rep = args.get(3).and_then(call_arg_str).unwrap_or_default();
    let g = if op == "//" { "g" } else { "" };
    format!("(({} =~ s/{}/{}/{g}r))", var, glob_to_regex(&pat), rep)
}
```

i.e. delete the dead `"/"` arm and fold it into the live one. Separately,
`param_value` should pass the node's real `StrStyle` through instead of
hardcoding `DoubleQuoted`, so a backend can mark an operand raw.

Please sanity-check one thing before landing: `rep` is interpolated into the
regex *body*, so it must have `/` and `@` escaped for Perl even though it is
not a pattern. The current `trim_matches('\\')` does not do that. I have NOT
verified the escaping of a replacement containing `/` or `@` — worth a test
(`${v/a/b\/c}`), since a wrong `\/` here would be a new silent corruption.

## Corpus impact

This is the highest-leverage single defect I found. Directly: `bench-strsubst`
(`front=`, `back=` both wrong). `bench-strsubst` and `parse-param-pattern-match`
are the two corpus cells that exercise single-slash substitution directly, and
`bench-strsubst` is one of the 57.

Measured reach: of the 57 cells, these are the substitution-family ones I
confirmed broken — `bench-strsubst`, `parse-param-pattern-match`,
`parse-substring-double-colon`, `063_04`/`064_03` (which are also Gap 1) and
`062_hard_to_lex`. I did not get to measure how many *other* cells' diffs are
dominated by a dead substitution, because the gate reports one verdict per
file, not per line. Given that the failure is silent, I'd expect the true
number to be higher than the direct list — a cheap way to size it is to apply
the fix and re-run `./fail`.

## Verification

```bash
cd /home/llm/sh2loop
printf 's=abc:def:ghi; echo "${s/abc/XYZ}"\n' > /tmp/t1.sh
otranspilerl/target/debug/otranspilerl-cli --target pl /tmp/t1.sh | grep 's/'
# must be:  print((($s =~ s/abc/XYZ/r)), "\n");
bash harness/pg-one-case.sh bench-strsubst.sh   # expect PASS
```

---


## Corpus impact

The `perl-generator` gate is at 60 failures (trusted file still says 57 — the
worker's own prompt is generated from an older run and understates it). Of
those, these are the pure "generated Perl does not compile" cells, which are
the worst class because the whole file is lost:

- `063_04_complex_parameter_expansion.sh`
- `063_hard_to_parse.sh`  (same `near "$(echo"` shape, line 258)

`dq-hashbang-multiline-assign.sh` is a *different* defect and I am fixing it
in the generator, not escalating it: a command substitution wrapping a
redirect list is truncated mid-`print(` by the capture/restore wrapper, leaving
`print("; open(STDOUT, ...) or die "capture: $!\n"` — unbalanced quotes.

## Verification

```bash
cd /home/llm/sh2loop
bash harness/pg-one-case.sh 063_04_complex_parameter_expansion.sh
# expect: no `syntax error`, and the first line to be `computed`
```

## OUTCOME: rejected: Perl renderer (param_value/param_inner_perl) — perl-only surface, out of scope this iteration.
