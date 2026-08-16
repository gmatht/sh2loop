> RESEND (this is a re-filing). The 23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# shir-perl (RE-FILED): preserve process substitution through the ShIR

## NEED

(Re-file: `perl-shir-20260806-1930.md` was moved to done/ in the
21:07 batch WITHOUT being implemented — the batch implemented the
shir-passes store-lift instead; no rejection note was appended.)

`ast_to_ir` (src/shir.rs) must not drop process substitution: it emits
`IrRedirect { mode: "unsupported", target: Str("") }` for `<(cmd)` /
`>(cmd)` — the inner command text is lost. Emit the redirect with the
inner command text in the target:

- `<(echo hi)` → `IrRedirect { fd: None, mode: "process-in", target: Str("echo hi") }`
- `>(cmd)`     → `IrRedirect { fd: None, mode: "process-out", target: Str("cmd") }`

`IrRedirect.mode` is a free string (shir_json round-trips it — no
contract/deserializer change). **The renderer side is ALREADY LANDED**
(`cb78188`: append_redirect_frag emits ` <(CMD)` / ` >(CMD)` for these
modes, and the bash -c fallback expands them natively) — this is a
one-file change in ast_to_ir and the ~8 blocked files pass with zero
further renderer work.

## WHY

Files blocked: 012/040/041/042_process_substitution*.sh,
096_head_procsub.sh, process-substitution.sh, 070_cmp_basic.sh,
019_grep_regex.sh (`grep -f <(echo …)` emits "option requires an
argument" — the argument vanished).

## MINIMAL-CORE-CHANGE

In ast_to_ir's redirect lowering: match the parser's
`RedirectOperator::ProcessSubstitutionInput/Output` (already parsed as a
`Command`), reconstruct the inner command to shell text, emit the
mode/target above.

## FAILING-CASE

```sh
diff <(echo a) <(echo b)
grep x <(echo xy)
```
Current: `--shir` emits `{"mode":"unsupported","target":{"value":""}}`;
`--shir-in-perl` dies "(redirect mode)". Expected: `process-in` modes →
`bash -c` gets ` <(echo a) <(echo b)` → passes
harness/ir-perl-metric.sh.

## OUTCOME: implemented
