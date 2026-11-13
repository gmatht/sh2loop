# `dq_value_expr` splices a nested `$(…)`/backtick into the `bash -c` payload as RAW PERL

**Filed by:** the Perl GENERATOR worker
**When:** 2026-10-02 10:05
**Class:** shared-renderer value-reconstruction bug (silently wrong output, exit 0)
**Gate effect:** at least 2 corpus examples (`qx-var-builtin-cd.sh`,
`dot-source-lib.sh`) print the wrong thing / nothing while exiting 0.

## NEED

`ir.rs::dq_value_expr` must **return `None`** when the double-quoted content
contains a command substitution (`$(` or a backtick), so the caller falls back
to the plain-`bash -c` text path that evaluates it correctly.

## WHY

`dq_value_expr` converts a double-quoted word into a Perl expression which is
then spliced into a `q{…}` **shell command string**. Its only structural guard
is:

```rust
fn dq_value_expr(content: &str) -> Option<String> {
    // A backslash escape inside the double quotes (`\"`) changes the
    // shell-level meaning; refuse so the caller keeps the previous path.
    if content.contains('\\') {
        return None;
    }
    …
```

The `\\` guard covers escapes; **nothing covers `$(`**. The identifier check
farther down is applied ONLY to a `$`-expansion it recognised — a leftover
`$(` falls through to the `else` branch (`chars[i] != '$'`, so it is pushed as
literal text) and is emitted verbatim inside the `q{…}`.

So `"$(dirname "$0")"` is not refused and not transformed: it is copied
**character-for-character** into the reconstructed command text, and bash is
handed a Perl expression as a literal WORD.

### Minimal failing case

```console
$ cat /tmp/qxt.sh
#!/bin/sh
script_dir=$(cd -- "$(dirname "$0")" && pwd)
echo "$script_dir"

$ otranspilerl-cli --target pl /tmp/qxt.sh | tail -1
$script_dir = do { … __sh_pipe_capture(q['cd' '--' "do { my $__sh_cap; $__sh_cap
  = (do { require File::Basename; File::Basename::dirname($0) }); … }" && 'pwd'],
  "pipefail") };  # line 2

$ bash /tmp/qxt.sh
/home/llm/sh2loop/sh2perl/examples

$ # running the generated perl:
bash: line 1: cd: do { my ;  = (do { require File::Basename; …
    File::Basename::dirname(bash) }); … }: No such file or directory
                                     ← stdout is EMPTY, exit status 0
```

The generated program **compiles**, **runs**, prints **nothing**, and exits
**0** — so the strict `./fail` gate reports `stdout mismatch` rather than a
crash, and it reads as a content bug rather than a dispatch bug.

## MINIMAL-CORE-CHANGE

One guard, mirroring the existing `\\` one:

```rust
    // A COMMAND SUBSTITUTION nested inside the double quotes is not a value
    // `dq_value_expr` can produce — it is a whole command whose output becomes
    // the value. Splicing it hands bash a Perl expression as a literal WORD.
    if content.contains("$(") || content.contains('`') {
        return None;
    }
```

Returning `None` sends the caller back to
`sh_cmd_value_expr` → `safe_perl_q_string(cmd)` → `system('bash', '-c', …)`,
which runs `"$(dirname "$0")"` correctly as a shell command substitution. No
signature change; `dq_value_expr` is private to `ir.rs` and already returns
`Option`.

## FAILING-CASE

```console
$ cd /home/llm/sh2loop
$ bash harness/pg-one-case.sh qx-var-builtin-cd.sh
=== qx-var-builtin-cd.sh FAIL  bash=0 perl=0
--- stdout diff (bash < | perl >) ---
1c1
< /home/llm/sh2loop/sh2perl/examples
---
>
--- perl stderr ---
bash: line 1: cd: do { my ;  = (do { require File::Basename;
  File::Basename::dirname(bash) }); … }: No such file or directory
```

A second example with the same signature is `dot-source-lib.sh`
(`coreutils-ffi: unknown util '.'` — the `$(. lib)` form is likewise mangled),
though it additionally needs the `.`/source builtin routed correctly, so it
may not go fully green on this change alone.
## OUTCOME: rejected: Perl renderer (`dq_value_expr`) — perl-only surface, out of scope.
