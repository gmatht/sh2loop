# Caveats — Known Limitations

These are shell constructs that the translator cannot handle correctly,
along with the reason and any workaround.

## `declare -p` — Variable Metadata Output

`declare -p varname` prints a variable's type, name, and value in
bash-specific format (e.g. `declare -A info=([key]="value" ...)`).
No Perl equivalent exists. Tests that used `declare -p` have been
rewritten to use sorted key=value output instead.

**Affected tests:** 064_22, 064_hard_to_generate (fixed)

## Feature-Gated Zsh Syntax

Some `.sh`/`.zsh` files in the test corpus contain Zsh-specific syntax
protected by feature gates (e.g. `case "$_KUBE_PS1_SHELL" in "zsh") …`).
The translator parses both branches even though bash would never execute
the Zsh path at runtime.  If the Zsh branch contains constructs that
sh2perl cannot translate (e.g. `setopt`, `autoload`, `zmodload`), the
file as a whole will fail generation even though it would work correctly
when sourced under bash.

**Mitigation:** Files with unguarded Zsh syntax should be moved to
`sh.disabled/`.  Files with properly feature-gated Zsh syntax are
acceptable but may produce false-positive failures during generation.


`eval "$name() { $body }"` where `$name` and `$body` are runtime
variables cannot be translated because the function name and body
are unknown at compile time. The translator falls back to
`system('bash', '-c', "eval ...")`, but the function definition
is lost when the subprocess exits.

**Affected tests:** 063_15 (removed)

## Hash Iteration Order

Perl's `values %hash` returns values in randomized order (security
feature since Perl 5.18), while bash preserves insertion order for
associative arrays. Tests that depend on iteration order have been
fixed by sorting output.

**Affected tests:** 064_07 (fixed)

## Process Substitution `<(...)` in Backticks

Process substitution inside backtick command substitution
(e.g. `` `comm -23 <(sort a) <(sort b)` ``) is only partially
supported. The translator may fall back to `system('bash', '-c', ...)`
for complex cases.

**Affected tests:** 064_09 (still failing)

## `trap` — Signal Handlers

Bash's `trap` builtin has no direct Perl equivalent. The translator
emits a comment `# Builtin command 'trap' not implemented` instead.

**Affected tests:** 064_23 (still failing)
