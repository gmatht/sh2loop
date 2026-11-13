# The IR cannot say "this word was unquoted", so an empty unquoted expansion keeps one word

Filed from the C backend (`sh2perl/src/c_backend.rs`, `for` lowering,
`items` path) 2026-11-04. Found while modelling `_sh_split`; the C
renderer cannot fix it alone, and neither can any other backend, because
the distinction is **already gone** by the time a backend sees the IR.

## The divergence (measured, real bash)

```
$ e=""; n=0; for w in $e;   do n=$((n+1)); done; echo $n     # 0
$      n=0; for w in "";    do n=$((n+1)); done; echo $n     # 1
```

An **unquoted** expansion that yields the empty string contributes ZERO
fields (POSIX 2.5.6 word splitting); a quoted empty literal is ONE empty
field. `harness/ifs-probe.sh` case `52_xfail_empty_for` pins the C
divergence (1 where bash has 0) and case `52b` pins the half that must
NOT change (quoted `""` → 1).

## Why no backend can fix it

The two programs produce **byte-identical shIR**:

```json
{"type":"For","var":"w","iter":{"type":"Array","elements":[
    {"style":"DoubleQuoted","type":"Str","value":""}]}}
```

`StrStyle` (`sh2perl/src/ir.rs:304`) is
`SingleQuoted | DoubleQuoted | Command | Heredoc | Raw` — there is no
value for "came from an unquoted expansion", so an empty `Str` cannot
tell the renderer which of the two bash outcomes it means. (The C
renderer emits `static const char* _for_w_0[] = {""};` for both, which is
right for the quoted case and wrong for the unquoted one.)

## Proposed minimal change (core)

1. `ir.rs`: add `StrStyle::Unquoted` (serde name `"Unquoted"`).
2. Store: the word-part → `Str` conversion marks a part that had
   unquoted-expansion origin with it. Two places fold an unquoted var
   into a literal and lose the origin today — `transforms/copy_propagation.rs`
   and `transforms/interp_fold.rs`; the fold must carry the style over
   from the source word rather than emitting `DoubleQuoted`.
3. Consumers: an `Array` element that is `Str("")` with
   `StrStyle::Unquoted` contributes **no** word. Everywhere else the new
   variant behaves exactly like `DoubleQuoted` (it is still a single
   string value in a word), so the other backends need no semantic
   change — only a `match` arm.

Semantics worth keeping: in a *non-list* context the distinction does
not exist (`v=$e` and `v=""` are both the empty string), so only the
`Array`/word-list consumers act on it.

## Acceptance

- The two shIRs above must differ (one `Unquoted`, one `DoubleQuoted`).
- `harness/ifs-probe.sh 52` must PASS and `52b` must stay PASS.
- The C model already states the contract this enforces:
  `c_str_helpers.rs` `f14` (`ifs_fields("")` is the EMPTY field list) and
  `f15` (the one-element list the renderer emits is observably different
  from it), both `by (compute)`.

## Blast radius

`StrStyle` is a shared enum: adding a variant is mechanical for every
backend (`c, rust, go, js/estree, perl, zig, java, python, fish, zsh`)
but must be a single core change, not per-backend forks — hence this
request rather than a patch.
