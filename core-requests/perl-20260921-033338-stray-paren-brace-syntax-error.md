# core bug: a stray top-level `)` / `}` is recoverable, so bash's exit-2 verdict is lost

> **STATUS: RESOLVED downstream (2026-09-21) — no core change needed for
> the gate.** The two `./fail` failures are fixed by the shared transform
> `sh2perl/src/transforms/stray_reserved_word.rs` (sh2perl `4723295a2`,
> workspace `35d722a8`), which detects an `exec`/`builtin` whose NAME is a
> bare `)` / `}` and lowers it (and the tail) to the abort, preserving the
> statements bash already ran. `./fail` 304 → 306 passed, no regressions;
> the exit-code failure class is empty.
>
> This request is kept OPEN as a *parser-correctness* item, not a gate
> item. The transform is a shIR-level patch over a parser gap: the parser
> still accepts `)` as a command name, and an unquoted `)` used as an
> *argument* (`echo hi )`) is dropped before the transform can see it
> (the args array arrives empty). Fixing the parser remains the right
> long-term shape — see NEED below — and would make the transform
> redundant.

## NEED
`parser/commands.rs` should treat a stray top-level `ParenClose` /
`BraceClose` as a parse failure — the same treatment the `DoubleSemicolon`
arm already got — instead of "recovering" it as a literal command named
`)` / `}`.

**The error must carry the commands parsed BEFORE the offending line**,
because bash has already executed (and flushed) them. Today
`parse_with_lines` returns a bare `Result<…, ParserError>`, so the error
path discards everything; the CLI fallback then prints nothing to stdout.
The two failing scripts each `echo "hello"` on line 4 and a stray `)`/`}`
on line 5 — bash prints `hello` and exits 2.

Filed from the perl-gate workstream; the parser is core/single-owner.

## FAILING-CASE
```sh
# sh2perl/examples/parse-unexpected-parenclose.sh
echo "hello"
)
echo "exit: $?"
```
```sh
# sh2perl/examples/parse-unexpected-braceclose.sh
echo "hello"
}
echo "done: $?"
```
`./fail` verdicts (perl target, bash reference) — these are the last two
exit-code failures in the perl gate:
- `parse-unexpected-parenclose.sh` — FAIL: exit code (bash=2 perl=127)
- `parse-unexpected-braceclose.sh` — FAIL: stdout mismatch, exit code (bash=2 perl=0)

## EVIDENCE
- bash for both: prints `hello` on stdout, then
  `syntax error near unexpected token`)'` on stderr, exit 2.
  (verified: `bash sh2perl/examples/parse-unexpected-parenclose.sh`)
- The separator loop already returns a hard error for `DoubleSemicolon`,
  with the rationale baked into the comment: *"a real parse failure, not a
  recoverable one. The old truncate-and-succeed recovery silently DROPPED
  the rest of the script and exited 0 … The CLI's parse-error fallback now
  reproduces bash's verdict."*
- The `ParenClose` arm immediately below does the **opposite**: it
  consumes the `)`, synthesizes `SimpleCommand { name: Word::literal(")") }`
  and returns `Ok((commands, lines))`. Its comment justifies this with
  *"the ESTree runner's stray-`)` path (exit 2) then matches bash; the Perl
  renderer's handling is best-effort."* That caveat has expired: the Perl
  backend now has the same parse-error parity (otranspilerl 797bc057 — an
  unparseable source renders a program that prints the diagnostic to
  stderr and exits 2), so the recovery is now strictly worse for perl too.
- The synthesized literal-command reaches every backend as a program to
  run, so bash's "execute the prefix, then abort" semantics are lost:
  - perl → `system('bash', '-c', q(')')); $CHILD_ERROR = $? >> 8;` → rc 127
  - shir → `{"func":"exec","args":[{"type":"Str","value":")"},{"type":"Array","elements":[]}]}`
- `line_start` already exists and is maintained for exactly this purpose.
  Its own comment says: *"bash parses/executes one line (list) at a time; a
  syntax error (`;;` or a stray `)` outside case/subshell) discards the
  whole line and aborts the rest of the script, so the parser truncates
  back to this index."* But the `;;` error path returns a bare `Err` and
  never uses it — so the intended truncation is not implemented on either
  error arm.

## FIX (proposed; needs the core owner's call on the API shape)
Either:

**(a) preferred — carry the prefix on the error.** Add a variant/beside
data so a syntax error reports the successfully-parsed prefix, e.g.
```rust
pub enum ParserError {
    …
    #[error("Invalid syntax: {0}")]
    InvalidSyntax(String),
    /// A syntax error at `line`: the commands BEFORE that line were parsed
    /// and bash has already run them.
    SyntaxErrorWithPrefix {
        #[source] inner: Box<ParserError>,
        commands: Vec<Command>,
        lines: Vec<usize>,
        line: usize,
    },
}
```
and at both error arms (`DoubleSemicolon`, `ParenClose`, `BraceClose`)
return it with `commands[..line_start]` / `lines[..line_start]`. The CLI's
parse-error fallback (otranspilerl/src/lib.rs, NOT core) then renders the
prefix followed by `exit 2`, which reproduces bash's verdict byte-for-byte
for both scripts.

**(b) minimal — just error out**, no prefix. Then both tests still fail,
but as *stdout mismatch* (`bash="hello"` vs `perl=""`) instead of the
current exit-code mismatch. This is a strict improvement in diagnosis (the
script no longer pretends `)` is a program) but does not turn the gate
green; do not take (b) if the goal is the gate verdicts.

Replace the arm with (mirroring `DoubleSemicolon`):
```rust
Some(Token::ParenClose) => {
    return Err(ParserError::InvalidSyntax(
        "unexpected `)` outside any subshell".to_string(),
    ));
}
Some(Token::BraceClose) => {
    return Err(ParserError::InvalidSyntax(
        "unexpected `}` outside any block".to_string(),
    ));
}
```
Placement note: this match is reached only for a *stray* `)` — a real
subshell body loop pre-checks `ParenClose`, and a real `}` is consumed by
the block/group parser — so grouping is unaffected. Confirm `Token::BraceClose`
even reaches this match (it may need a new arm; if a real `}` is consumed
earlier, verify with the two scripts before landing).

## VERIFICATION
```
./fail parse-unexpected-parenclose   # expect TEST PASSED (needs fix (a))
./fail parse-unexpected-braceclose   # expect TEST PASSED (needs fix (a))
./fail                               # exit-code class should reach 0
```
Also re-run `./fail parse-double-semicolon` and
`./fail parse-error-doublesemicolon` — they pass today with an empty
prefix (no stdout before the `;;`), so fix (a) must keep them green.
