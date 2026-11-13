# c-20261003-220000 — A1 lexes `true`/`false` inside a path word, splitting one command word into two

## NEED

A shell command word whose final path segment is exactly `true` or `false` is lexed
as **two separate words**, so the A1 contract loses the word boundary and every
backend renders a different command than bash.

Minimal case — the input is a single command word:

```sh
/bin/false
```

bash: exits **1**.

A1 (`otranspilerl-cli --shir --raw /bin/false.sh -`) produces:

```json
{"stmts":[{"expr":{"args":[
  {"type":"Str","style":"DoubleQuoted","value":"/bin/"},
  {"type":"Array","elements":[{"type":"Str","style":"DoubleQuoted","value":"false"}]}
],"func":"exec","purity":"Spawn","type":"Call"},"type":"Expr"}]}
```

i.e. command = `"/bin/"`, argv = `["false"]` — the single word `/bin/false`
became a **path prefix plus an argument**. The run is now
`bash -c '/bin/ false'`, which fails to parse, so every downstream status and
output diverges.

## WHY (user-visible, backend-independent)

This is a shared-parse defect, not a rendering choice. Any backend that lowers
`exec(cmd, args)` by emitting the command word and then the argument array
produces a *different program*:

| input | A1 cmd | A1 args | bash | c backend |
|---|---|---|---|---|
| `/bin/false` | `"/bin/"` | `["false"]` | exit 1 | exit **126** |
| `/bin/true`  | `"/bin/"` | `["true"]`  | exit 0 | exit **126** |
| `false`      | `"false"` | `[]`         | exit 1 | exit 1 (correct) |
| `/bin/wc`    | `"/bin/wc"` | `[]`        | ok     | ok (correct) |

Measured on the c backend (`harness/c-gate-run.sh` verdict logic), `/bin/false`
renders `_sh_word("/bin/")` + `_sh_word("false")` — the c renderer is faithfully
emitting a contract that is already wrong, so **no backend change can fix this**.

Note the split is *specific to the `true`/`false` keywords*: other builtin
basenames are unaffected (`/bin/wc`, `/bin/ls`, `/bin/sort` all stay one word),
and `false` alone (no slash) stays one word. Only a path **ending** in
`/true` or `/false` splits.

## MINIMAL-CORE-CHANGE

The `Token::True` / `Token::False` arms in `src/parser/words.rs`
(both sites: ~line 1169 and ~line 2011) consume the keyword as a *standalone*
word:

```rust
Some(Token::True) => {
    // Treat standalone 'true' as a normal word (e.g., `true` or `command || true`)
    lexer.next();
    Ok(Word::Literal("true".to_string(), None))
}
```

The comment already states the intent ("**standalone** `true`"), but nothing
enforces it: when `Token::True` arrives **mid-word** (after `/bin/` has already
been accumulated into the current word), the arm unconditionally ends the word
and starts a new one.

Minimal fix: at both sites, only take the standalone path when the keyword
begins a word — i.e. when the current word buffer is empty / the previous token
was a word separator (`Space`, `Tab`, `Newline`, `|`, `;`, `&`, `(`, `)`, …).
Otherwise fall through to the normal word-continuation handling so the literal
characters are appended to the word already in progress, yielding the single
word `"/bin/false"`.

Equivalently: the lexer should not raise a word-initial `True`/`False` keyword
token when the preceding character is part of the current word (e.g. when
`/bin/` precedes it) — the keyword classes `true`/`false` are only reserved as
whole words in bash.

Please also confirm the same guard applies at **both** occurrences (~1169 and
~2011); they look like duplicated word-parsing arms and only fixing one would
leave the bug live on the other code path.

## FAILING-CASE

Repro (no build required, `otranspilerl-cli` only):

```sh
printf '/bin/false\n' > /tmp/pp.sh
otranspilerl-cli --shir --raw /tmp/pp.sh -   # -> cmd "/bin/", argv ["false"]
```

Behavioural check through the c backend (the case that surfaced this):

```sh
printf '/bin/false\n' > /tmp/f.sh
backends/c/target/debug/c_backend /tmp/f.sh > /tmp/f.c && cc /tmp/f.c -o /tmp/f.bin
bash -c 'exec -a "$0" "$1"' /tmp/f.sh /tmp/f.bin; echo "c=$?"    # 126
bash /tmp/f.sh;                            echo "bash=$?" # 1
```

Expected after the fix: A1 emits a single `Str("/bin/false")`, and the c
backend exits **1**, matching bash.
## OUTCOME: implemented

The lexer cannot distinguish a word-initial keyword from a mid-word one
(logos' `#[token("true")]` matches ANYWHERE), so the guard belongs in the
word parser. Both sites (`parse_word_inner` ~1184/2026, and the duplicated
`parse_word_no_newline_skip_inner`) now route `Token::True`/`Token::False`
through the contiguous-word combine loop, and both word-INITIAL gates include
them so a leading keyword can still continue (`false.sh`).

Verified on the A1 (the contract that was already wrong, so no renderer change
is involved): `/bin/false` and `/bin/true` emit a SINGLE `Str("/bin/false")`
with an empty argv (was `"/bin/"` + argv `["false"]`), `false.sh` is one word,
`a=true` is one word, and standalone `true`/`false` still lower to the
`builtin` call in command position. `./fail` 562/562, `./fail-estree`
562/562, `cargo test --lib` unchanged (the same 14 pre-existing fish/c-backend
failures with and without the change).

Commit: sh2perl b6c50071a.
