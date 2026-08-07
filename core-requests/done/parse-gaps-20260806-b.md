> RESEND (this is a re-filing). The 23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# parse gaps: four files fail `debashc --shir` outright (empty JSON)

## NEED

`debashc --shir` emits NOTHING (parser error → empty output) for:
`multiple-awk-in-dqs.sh`, `parse-paren-after-do.sh`,
`parse-unexpected-end-of-input.sh`, `subshell-sed-squote-dquote.sh`.
The ShIR path (and the frontend ladder's probe) dies at the parser; the
ESTree backend covers them via the bash-wrapper fallback, but the
`--shir` contract gets no output at all.

## WHY

These are the only corpus files where `--shir-in-perl` can't even try
(empty JSON → "ShIR JSON ingress: invalid JSON: EOF"). Every other
failing file at least renders. Fixing the parser unblocks the ShIR
pipeline for them entirely (and shrinks the parse-failure count the
frontends also see).

## MINIMAL-CORE-CHANGE

Parser fixes in src/parser/ (the estree worker owns it). The four cases:

1. `multiple-awk-in-dqs.sh` — awk `{print ...}` braces inside double
   quotes confuse the parser (likely a brace-balance/quote-state bug).
2. `parse-paren-after-do.sh` — `do` followed by a `(` (grouped cmd)
   mis-parses.
3. `parse-unexpected-end-of-input.sh` — a genuinely truncated/invalid
   script — verify the corpus copy is the intended content, then decide:
   either fix the parser to fail GRACEFULLY (emit the bash-wrapper
   fallback through --shir) or drop the file.
4. `subshell-sed-squote-dquote.sh` — subshell + sed with mixed single/
   double quotes.

## FAILING-CASE

```sh
# multiple-awk-in-dqs.sh (the parser-balance case)
out=$(awk '{print $1, $2}' file | awk '{print $2}' )
echo "$out"
```

Current: `debashc --shir` → empty JSON. Expected: valid A1 (or at worst
a graceful fallback marker, never empty).
