# Fixes for test_purify.pl 028_dirname_basic

## Bug 13: dirname builtin emits `print` instead of bare expression in inline mode (Rust)

In `dirname.rs`, the `generate_dirname_command` function used `print $dirname_output;` when `input_var` was empty (standalone command in backtick context). When purify.pl wrapped the result in `__bt(do { ... })`, the `do` block's last expression was the return value of `print` (which is `1`), causing the backtick to return `"1"` instead of the actual dirname output.

**Fix:** Check `generator.inline_mode` — when true, emit `$dirname_output;` (bare expression) so the `do` block returns the captured output value instead of the `print` return value. Same pattern as Bug 12 fix for basename.

## Bug 14: Keyword tokens (Local, True, False, etc.) split path components during parsing (Rust)

The Logos-based tokenizer emits keyword tokens (e.g. `Local` for "local", `True` for "true") regardless of context. When a path like `/usr/local/bin/script.sh` was tokenized, the `/usr/` part was parsed as a bare word, but then `Local` was emitted as a keyword token that did NOT match any entry in `parse_word()`'s bare-word match arm, so the combination loop broke. The remaining `local`, `/bin`, `/script.sh` were parsed as three separate arguments, producing incorrect behavior when the command string was later reconstructed via `generate_command_string_for_system()`.

The same issue existed in two places:
1. `parse_word()` in `parser/words.rs` (line ~170, used for command names)
2. `parse_word_no_newline_skip()` in `parser/words.rs` (line ~530, used for arguments)

A similar issue would affect any path containing keyword-like strings (e.g., `/usr/bin/true`, `/usr/bin/false`).

**Fix:** Added keyword tokens (`Local`, `True`, `False`, `Source`, `Set`, `Declare`, `Unset`, `Export`, `Readonly`, `Typeset`, `Shift`, `Eval`, `Exec`, `Trap`, `Wait`, `Exit`, `Shopt`) to both the initial-match set and the inner-loop match arm in both `parse_word()` and `parse_word_no_newline_skip()`. These tokens are now consumed as part of bare-word combinations, so path components like `local` in `/usr/local/bin/` stay as part of the path instead of being split out as separate keyword tokens.

# Fixes for test_purify.pl 024_rm_basic

## Bug: rm shell fallback qx stderr leaks through local *STDERR (Rust)

In `rm.rs`, the shell fallback for unrecognized options (like `-P`, `--preserve-root`) generated a `qx{}` command whose stderr was supposed to be suppressed by Perl-level `local *STDERR; open STDERR, '>', '/dev/null'` from the redirect handler. However, `local *STDERR` does not reliably suppress stderr from `qx{}` child processes on all platforms — the child inherits fd 2 via `dup2()` during fork, but the local-scope restore can leave the fd pointing to `/dev/null` after the block exits, or the redirection may not take effect for the child at all depending on Perl internals. This caused error messages like "invalid option -- 'P'" and "it is dangerous to operate recursively on '/'" to appear on stderr when they should have been suppressed.

**Fix:** Append `2>/dev/null` to the reconstructed shell command string inside the `qx{}` fallback, so stderr is suppressed at the shell level (which always works reliably). The exit code is still captured via `$?`, so OR/`||` chains continue to function correctly.

# Fixes for test_purify.pl 048_nested_control_flow

## Bug 1: grep simple command handler (Rust)

In `perl_generator.rs`, the grep handler for normal mode (no flags) only set `$found = 1` and `last` when finding matches, instead of outputting the matching lines. This caused backtick commands like `` `grep 'line' nested_test.txt` `` to return `1` instead of the matching lines.

**Fix:** Changed the generated code to accumulate matching lines into `$result` (inline mode) or `print $line` (non-inline mode), so the output matches the original grep behavior.

## Bug 2: ls -l pipeline handler with file arguments (Rust)

In `perl_generator.rs`, the `ls -l` pipeline handler used `opendir()` on its argument unconditionally. When the argument was a file (not a directory), `opendir()` failed, leaving `@ls_files` empty and producing `"total 0\n"` as output. This broke commands like `` `ls -l nested_test.txt | cut -d' ' -f1` ``.

**Fix:** Added a runtime check: if the argument is a regular file (`-f`), treat it as a single entry in `@ls_files` and skip the `opendir`. Also suppressed the "total N" prefix for single-file ls output since `ls -l file` does not emit a total line.

## Bug 3: Perl variables in backtick commands (purify.pl)

When `purify.pl` extracted backtick commands containing Perl variables (e.g., `` `echo "$lines[$i]" | tr 'a-z' 'A-Z'` ``), it passed them to `debashc` which interpreted Perl `$variables` as shell variables, producing incorrect conversions. `$lines[$i]` was parsed as a shell array access `${lines[$i]}` rather than a Perl array element.

**Fix:** In `process_single_backtick_string`, check if the raw command text contains unescaped `$variable` references before calling `debashc`. If detected, skip `debashc` entirely and use the IPC::Open3 fallback which correctly handles Perl variable interpolation. Also enhanced `_perl_quote_interpolating` to recognize `$identifier[...]` as a single Perl array-access expression rather than splitting it into `$identifier`, `[`, and `...` parts.

# Fixes for test_purify.pl 051_remaining_examples

## Bug 4: find handler converts directory arguments to regex (Rust)

In `perl_generator.rs`, the find handler's argument collection loop applied `convert_glob_to_regex()` to ALL non-`.` non-`-name` arguments. The directory argument (e.g. `test_dir_051`) was converted to a regex pattern like `^test\_dir\_051$`, making it an invalid directory path for `File::Find::find()`.

**Fix:** Added a `after_name` flag that tracks whether we've seen `-name`. Only arguments after `-name` are converted through `convert_glob_to_regex`; directory paths are passed through as-is.

## Bug 5: cut `-fN-` range not handled (Rust)

In `perl_generator.rs`, the cut handler parsed field specifications as individual `usize` values. The range `N-` (e.g. `-f2-` meaning "fields 2 through end") failed to parse as a valid integer and was silently dropped, defaulting to field 1. This broke commands like `cut -d' ' -f2-`.

Two issues: (a) the parser did not recognize `N-` as a range suffix, and (b) the shell tokenizer splits `2-` into two tokens (`2` and `-`), so the parser also did not handle a standalone `-` token following a numeric field.

**Fix:** Added a `CutField` enum with `Single(usize)` and `RangeFrom(usize)` variants. The field parser now handles `N-` via `strip_suffix('-')` and also detects a standalone `-` token after a numeric field, converting it to a `RangeFrom`. Code generation emits an array slice `@cut_f[Start..$#cut_f]` for ranges instead of individual field pushes.

## Bug 6: grep pipeline handler triggers glob branch on pattern (Rust)

In `perl_generator.rs`, the pipeline grep handler's glob-detection check at line 4738 checked ALL command arguments for glob characters (`*`, `?`, `[`, `{`). When the grep PATTERN contained these characters (e.g. `grep 'Line [13]'`), it triggered the glob branch which treats input data lines as filenames to grep through, producing empty output.

**Fix:** Exclude the pattern argument from the glob character check by comparing against the already-parsed `pattern` variable. Only non-pattern arguments are checked for glob characters.

## Bug 7: `&&` between piped sub-commands overwrites output instead of accumulating (Rust)

In `perl_generator.rs`, the `generate_pipeline` method's pipe-handling branch (`has_pipe == true`) processed ALL pipeline commands sequentially through a single `$output_{id}` variable, ignoring `&&`/`||` operators. When a pipeline contained both pipes and `&&` (e.g. `cat file | wc -l && cat file | wc -w`), each `&&`-separated sub-pipeline overwrote `$output_{id}` with its result, so only the last sub-pipeline's output was returned.

**Fix:** Added an accumulation variable `$output_total_{id}` and logic at `&&`/`||` boundaries to save the current sub-pipeline's output into the total and reset for the next sub-pipeline. After the loop, the final output is set to the accumulated total. Also changed the declaration from `my $output_{id};` to `my $output_{id} = '';` to avoid purify.pl's regex that strips bare `my $var;` declarations.

## Bug 8: mv generator uses File::Copy::move instead of Perl built-in rename (Rust)

In `mv.rs`, the file move operation was implemented using `require File::Copy;` and `File::Copy::move()`. This broke `test_purify.pl`'s "bare mv backtick" assertion which expects the generated code to use Perl's built-in `rename()` function (`qr/\brename\(/`). The assertion failure prevented the test from reaching other test files (including 004_cat_basic).

**Fix:** Replaced `require File::Copy;` / `File::Copy::move()` with Perl's built-in `rename()` function.

# Fixes for test_purify.pl 003__ls_basic

## Bug 11: ls and wc builtin handlers print output instead of returning value in inline mode (Rust)

In `simple_commands.rs`, the `ls` and `wc` builtin dispatch used `generate_ls_command()` / `wc` with `print $wc_output_N` regardless of whether the generator was in inline mode. When purify.pl wrapped the generated code for backtick commands (`__bt(do { ... })`), the `do` block's last expression was either the return value of `print` (value `1`) or `$ls_success = 1`, causing the backtick to return `"1"` instead of the actual command output.

**Fix:** Check `generator.inline_mode` in both dispatch paths. For `ls`, call `generate_ls_for_substitution()` (which returns a value-expression `do` block). For `wc`, emit `$wc_output_N;` as the last expression instead of `print $wc_output_N;`.

# Fixes for test_purify.pl 001_echo_basic

## Bug 9: printf inline mode uses `printf` instead of `sprintf` (Rust)

In `printf.rs`, the `generate_printf_command` function emitted `printf(...)` (which prints to STDOUT and returns byte count) even in inline mode (backtick context). When purify.pl wrapped the result in `__bt(do { ... })`, `$output` got the byte count instead of the formatted string. Additionally, Perl's `sprintf`/`printf` do not cycle the format string for remaining arguments like shell printf does — shell `printf '%s\n' A B C` produces `A\nB\nC\n` while Perl `sprintf "%s\n", "A", "B", "C"` only returns `"A\n"`.

**Fix:** In `printf.rs`, when `generator.inline_mode` is true and `output_var` is `None`, emit `sprintf()` (no-args) or `join('', map { sprintf(FORMAT, $_) } (ARGS))` (1-specifier format) or a chunked `while`-loop with `splice` (multi-specifier format). A `count_format_specifiers` helper determines the chunk size.

## Bug 10: purify.pl system() detection regex misses `system LIST` syntax (purify.pl)

In `purify.pl`, the backtick conversion path checks for `system()` calls generated by debashc and falls back to IPC::Open3 if found. The regex `/\bsystem\s*\(/` only matched `system(...)` with parentheses, but debashc sometimes emits `system LIST` syntax (`system 'sh', '-c', "..."`) which has no parentheses. This caused commands like `` `sh -c 'echo -e "A\\nB"'` `` to use `system` directly, whose return value (exit code 0) was captured instead of the actual output.

**Fix:** Broadened the regex to `/\bsystem\b/` so it matches any `system` keyword regardless of syntax.

# Fixes for test_purify.pl 027_basename_basic

## Bug 12: basename builtin emits `print` instead of bare expression in inline mode (Rust)

In `basename.rs`, the `generate_basename_command` function used `print $basename_output;` when both `output_var` and `input_var` were empty (standalone command in backtick context). When purify.pl wrapped the result in `__bt(do { ... })`, the `do` block's last expression was the return value of `print` (which is `1`), causing the backtick to return `"1"` instead of the actual basename output.

**Fix:** Check `generator.inline_mode` — when true, emit `$basename_output;` (bare expression) so the `do` block returns the captured output value instead of the `print` return value.

# Fixes for test_purify.pl 042_checksum_verification

## Bug 15: Redirect `do` block returns `1` instead of `0` as exit status, breaking `&&` chains (Rust)

In `command_dispatcher.rs`, the `do { ... }` block for output redirection (`>`) used `close $original_stdout` as its last statement. Since `close` returns `1` on success, the block's value was `1`. When this `do` block was used as the left side of `&&` via `if (do { ... } == 0)`, the condition `1 == 0` evaluated to false, causing the right side of `&&` to never execute. This broke backtick commands like `` `sha512sum file > checksum.sha512 && sha512sum -c checksum.sha512` `` where the check step was skipped.

**Fix:** Added `0;` after `close $original_stdout` so the redirection `do` block returns `0` (success exit code) instead of `1`.

## Bug 16: sha256sum/sha512sum stdin/pipe output lacks trailing newline (Rust)

In `sha256sum.rs` and `sha512sum.rs`, the generated expressions for stdin and pipe input (the `files.is_empty()` branch) emitted `<hash>  -` without a trailing newline. The external `sha*sum` tools always print a trailing newline, so backtick commands like `` `cat file | sha512sum` `` captured the output without the final newline, causing subsequent `print` statements to appear on the same line.

**Fix:** Changed the suffix from `'  -'` to `"  -\\n"` in both the stdin and input-var branches of both `sha256sum.rs` and `sha512sum.rs`, so the generated expression includes a trailing newline.

# Fixes for test_purify.pl 043_string_processing

## Bug 17: strings builtin prints file-not-found error to STDERR instead of capturing into backtick result (Rust)

In `strings.rs`, the `generate_strings_command` function used `print {*STDERR}` when a file could not be opened. In backtick context with `2>&1`, the redirect handler generates `local *STDERR; open STDERR, '>&', *STDOUT;` which redirects the `print {*STDERR}` output to the script's real STDOUT — but the `do` block's return value (captured by the backtick via `__bt()`) is the last expression `$output_0 = $combined_output`, which does NOT include what was printed via the dup'd handle. This caused the error message to appear as raw output instead of being captured into the backtick variable.

**Fix:** Changed the else branch (file-not-found) in the strings builtin to append the error message to `$combined_output` instead of printing to `*STDERR`. The error message is now part of the captured output, matching the shell behavior of `` `strings nonexistent_file.txt 2>&1` `` where stderr is merged into stdout.

# Fixes for test_purify.pl 051_remaining_examples (continued)

## Bug 18: `&&` chain in backtick context emits syntax error and discards early-stage output (Rust)

In `logic_commands.rs`, `generate_logical_and` had two issues in its else branch (handling Pipeline, And, and other non-Simple/non-Redirect commands):

1. **Missing semicolon separator:** The else branch appended the pipeline's do-block output (which ends with `}`) directly followed by `$CHILD_ERROR == 0` without a `;` separator. Perl interpreted the do-block expression `... } $CHILD_ERROR` as a malformed expression — "Scalar found where operator expected" — because there was no operator between the closing `}` and `$CHILD_ERROR`.

2. **Output not accumulated in inline mode:** The function generated `if (do { LEFT $CHILD_ERROR == 0 }) { RIGHT }`, which uses the left side only as a condition. In backtick context (`inline_mode`), the `__bt(do { ... })` wrapper captures the `if` statement's return value — which is only RIGHT's result. LEFT's stdout is lost even when it succeeds, so `A && B && C` in backticks returned only C's output.

**Fix:**
1. Added `;\n` after the command in the else branch, terminating the pipeline's do-block expression so `$CHILD_ERROR == 0` is a separate statement.

2. Added an `inline_mode` fast-path that replaces the `if (do { LEFT ... }) { RIGHT }` structure with an accumulation do-block:
   ```perl
   do {
       my $__and_acc = q{};
       LEFT;
       if ($CHILD_ERROR == 0) {
           $__and_acc .= do { RIGHT };
       }
       $__and_acc;
   }
   ```
    For `Redirect` commands (whose generated code returns the exit code `0`, not stdout), the left side is executed as a bare statement without accumulating. For all other command types, the left side's output is captured via `$__and_acc = do { LEFT }`. RIGHT's output is always appended on success.

## Bug 19: Redirect exit code not captured into `$CHILD_ERROR` in inline `&&` handler (Rust)

In `logic_commands.rs`, the inline-mode `&&` handler's `Redirect` path emitted the redirect's `do { ... }` block as a bare statement (`output.push_str(&left_cmd)`), discarding its return value. Since `$CHILD_ERROR` was never set from the redirect's exit code, the subsequent `if ($CHILD_ERROR == 0)` check used whatever stale/undefined value `$CHILD_ERROR` had. In this case, `$CHILD_ERROR` was `undef` (never set by prior fork/exec system() calls), and `undef == 0` is true in Perl, so the right side of `&&` did execute — but the first character of the redirect block's result (`0`) was lost because the accumulated output `$__and_acc` started empty and the right side's output was alone in it. However, if `$CHILD_ERROR` had been a non-zero value (e.g., from a previous failed command), the right side would have been skipped entirely.

**Fix:** Wrap the redirect's generated code in `$CHILD_ERROR = do { ... };` so the redirect's exit code is captured into `$CHILD_ERROR`. This ensures the `if ($CHILD_ERROR == 0)` check sees the correct exit status of the redirect operation, matching the behavior of shell `&&` chains.

# Current status

All 54 tests in `test_purify.pl` pass with 0 failures (`PROGRESS 54:0`). No fix was needed for this invocation.

## Verification (2026-06-29)

Re-ran `test_purify.pl` after `cargo build` — all 54 tests pass (`PROGRESS 54:0`). All previously documented fixes (bugs 1–19) remain in place and working. No new failures detected; no code change required.

## Verification (2026-06-29, second invocation)

Re-ran `test_purify.pl` after `cargo build` — all 54 tests pass (`PROGRESS 54:0`). No failure to fix; the test suite confirms all previously applied fixes (bugs 1–19) continue to work correctly. No code change required.

## Verification (2026-06-30)

Re-ran `test_purify.pl` after `cargo build` — all 54 tests pass (`PROGRESS 54:0`). No failure to fix; the test suite confirms all previously applied fixes (bugs 1–19) continue to work correctly. No code change required.

# Fixes for freeze in 062_15_complex_local_variables.sh

## Bug 20: Infinite loop in `local` command handler with non-Literal args (Rust)

In `redirects.rs`, the `local` builtin handler at line ~1075 uses a `while i < cmd.args.len()` loop with manual `i += 1` at the bottom. The `_ =>` branch (handling non-`Literal`, non-`CommandSubstitution` args like `Variable` tokens) had `continue;` statements that skipped the `i += 1;` increment, causing an infinite loop when the parser produced a `Variable` token in the args list.

This was triggered by the shell script `062_15_complex_local_variables.sh` which contains:
```bash
local var3="$(echo "$var1" | tr '[:lower:]' '[:upper:]')"
```
The parser splits the `$(...)` command substitution at the inner `"` before `$var1`, producing `Literal("var3=\"$(echo \"")` and `Variable("var1")` as separate args to the `local` builtin. The `Variable` arg hit the `_ =>` branch which looped forever.

**Fix:** Added `i += 1;` before the `continue;` statements in the `_ =>` branch so the loop always advances.

## Bug 21: Code generation has no timeout protection

In `testing.rs`, the Rust code generation phase (`gen.generate(&commands)`) ran synchronously in the main thread with no timeout wrapper. An infinite loop during code generation (like Bug 20) would permanently freeze the test runner, since the `execute_with_timeout` wrappers only protect the shell execution and Perl process execution phases.

**Fix:** Wrapped `gen.generate(&commands)` in `execute_with_timeout(OperationType::CodeGeneration, ...)` (5-second default timeout) so a code-generation freeze is caught and reported as a test error instead of hanging forever.

## Bug 22: Perl wrapper functions lack reliable timeouts

All three Perl scripts (`main_loop.pl`, `main_loop_rust.pl`, `test_purify.pl`) used blocking I/O operations with no timeout or unreliable `alarm()`-based timeouts:

- **`main_loop.pl`'s `run_purify()`** read from a pipe via `while (<$pipe>)` with no timeout at all — if `test_purify.pl` froze, `main_loop.pl` hung forever.
- **`main_loop.pl`'s `system('opencode', ...)`** calls had no timeout — if opencode hung, the entire main loop froze.
- **`main_loop_rust.pl`** had the same two problems (pipe read loop and `system('opencode', ...)`).
- **`test_purify.pl`'s `run_backticks_with_timeout` / `run_system_with_timeout`** used `alarm()` + `$SIG{ALRM}` + `eval`, which is unreliable: `SIGALRM` may not interrupt blocking `waitpid()` or `read()` on all systems/kernels, and `alarm()` state can be corrupted by nested operations.

**Fix:**

1. **New `read_pipe_with_timeout()` function** (added to `main_loop.pl` and `main_loop_rust.pl`): Uses `select()` with a timeout on the pipe filehandle + `sysread()` for non-blocking reads. If the timeout fires, kills the child process with `TERM`/`KILL` before closing the pipe, preventing `close()` from blocking on `waitpid()`.

2. **New `run_system_with_timeout()` function** (added to all three scripts): Uses `fork()` + `exec()` + `waitpid()` with `WNOHANG` polling every 100ms. On timeout, kills the child with `TERM`/`KILL` and `waitpid()` to clean up.

3. **Replaced `test_purify.pl`'s `run_backticks_with_timeout()`**: Replaced `alarm()`-based backtick execution with `open(my $fh, '-|', '/bin/sh', '-c', $command)` + `select()`-based read with timeout + `sysread()` for output capture. On timeout, kills the child and returns `(undef, -1)`.

4. **Replaced `test_purify.pl`'s `run_system_with_timeout()`**: Replaced `alarm()` + `system()` with `fork()` + `exec()` + `waitpid()` polling with timeout.

5. **All `system('opencode', ...)` calls** in both `main_loop.pl` and `main_loop_rust.pl` are now wrapped in `run_system_with_timeout(300, ...)` (5-minute timeout).

6. **`snapshot_capture`/`snapshot_restore`** calls are wrapped in `run_system_with_timeout(30, ...)`.

All timeout values are in seconds and can be adjusted per call site.

# Current status

All known issues fixed. `test_purify.pl` continues to pass all 54 tests.
