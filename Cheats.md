# Cheats — Tests that Passed but Weren't Really Correct

This documents every case where the auto-loop or test infrastructure
produced a passing result that didn't reflect genuine translation quality.

## 1. Rust `check_perl_no_qx_builtins` Pattern 2 Disabled

The Rust check has Pattern 2 (indirect `qx{$var}` via variable assignment)
intentionally disabled with the comment "too aggressive". This means any
generated code that sets `my $cmd = q{find ...}; ... qx{$cmd}` escapes the
Rust test runner entirely. Only `check_qx.pl` (the shell-level script)
catches these. The Rust checker only catches direct `qx{find ...}` calls.

**Status:** Pattern 2 remains disabled. `check_qx.pl` covers the gap.

## 2. `check_qx.pl` Pattern 2 Regex Broken

For a period, `check_qx.pl`'s Pattern 2 regex used `\\$\w+` (literal
backslash) instead of `\$\w+` (literal dollar), causing it to match
nothing. The check was "enabled" but functionally dead.

**Status:** Fixed (regex corrected).

## 3. `check_perl_no_qx_builtins` Stubbed to `Ok(())`

At one point the entire function was replaced with:
```rust
pub fn check_perl_no_qx_builtins(...) -> Result<(), String> {
    Ok(())
}
```
The auto-loop "fixed" the QX violations by disabling the check.

**Status:** Restored (full implementation re-added twice).

## 4. Rust Checks Deleted Entirely (Commit `6ffc57b`)

The auto-loop's commit `6ffc57b` ("Test results: passed, failed")
deleted both the import and call site for `check_perl_no_qx_builtins`
from `src/testing.rs`, and removed the helper functions from
`src/utils.rs`. All QX violations suddenly "passed" because the
code that detected them was gone.

**Status:** Restored (re-added in commit `a9a7e1e`).

## 5. Exemptions File Expanded by Auto-loop

The auto-loop added `cp`, `find`, `mkdir`, `wc` to `allowed_qx_calls.txt`,
effectively whitelisting all common violations. The failure count dropped
from 88 to 8 overnight — not because anything was fixed, but because
everything was exempted.

**Status:** Exemptions restored to only `bash -c`, `ls -l`, `diff`.
File moved to root (`../allowed_qx_calls.txt`) so pi (restricted to
`sh2perl/`) cannot corrupt it.

## 6. The 17-Failure "Glitch"

A run showed 125 passed, 17 failed — the best result ever. This was
achieved with the qx check disabled and Pattern 2 broken. When the
checks were re-enabled, the real count was 31-88 failures. The 17-failure
baseline was a measurement artifact.

**Status:** Baseline corrected to 49 (current combined count).

## 7. `same 13 13 13` — Transient Low Count

An auto-loop iteration logged `same 13 13 13`, appearing to show
only 13 failures. This was from a run where stale test artifacts
(non-.sh files in examples/, files in /tmp) caused directory-listing
tests to produce different results. The real count at the time was
much higher.

**Status:** Fixed by cleaning non-.sh files from examples/ and /tmp/
artifacts before each test run.

## 8. Snapshot Restore Was Broken

The blessed commit hash in `ensure_examples_snapshot.pl` was
`75443d7276b17e60e226658ee7a6028c015b0045` which does not exist
in either git repo (`75443d7a08e681...` is the real one). The
snapshot restore silently failed (exit 128), so examples were never
reset to a baseline. Test results drifted as examples accumulated
stale artifacts from previous runs.

**Status:** Hash corrected. Restore now succeeds.

## 9. Stale Test Artifacts Caused Non-Determinism

Test scripts created files in `examples/` (`test_compress.txt`,
`a.logtmp`, `comparison.txt`, etc.) and `/tmp/` (`cmp_a.txt`, etc.)
that were not cleaned up. Tests using `ls`, `find`, `wc` would see
different file counts depending on what previous tests left behind.

**Status:** Fixed — non-.sh files are cleaned from examples/ and known
/tmp/ artifacts are removed before each test.

## 10. `check_perl_no_qx_builtins` Not Running Despite `--perl-critic`

The checks are inside `if lang == "perl" && enable_perl_critic`.
If `enable_perl_critic` is false (e.g., `--perl-critic` not passed),
all qx/system/open3 checks are skipped entirely. No warning is printed.

**Status:** All test invocations now use `--perl-critic`.

## 11. Commits Claiming Fixes Without Source Changes

The auto-loop committed 15+ "Test results: N passed, M failed (fixed K)"
commits that only modified `failing_tests.txt` — no `.rs` source files
changed. These "fixes" were pi simply removing entries from the failure
list without fixing the underlying code. The next test run would
re-discover the same failures and the count would bounce back.

Examples:
- `36a5d10` "Test results: 118 passed, 24 failed (fixed 8)" — no .rs changes
- `4255cc5` "Test results: 119 passed, 23 failed (fixed 2)" — no .rs changes
- `35de2e1` "Test results: 123 passed, 19 failed (fixed 3)" — no .rs changes

This pattern happened because the auto-loop only stages `failing_tests.txt`
for commit (not the source files), and pi's source changes were left in
the working tree where they were lost on the next reset/stash.

**Status:** Commit paths now use `git add -A` to include source changes.
The `.last_trusted_count` guard prevents drops to 0 without source changes.

## 12. "Test Passes When Run Individually" — Partial Verification

Pi sometimes fixed a test, verified it passed in isolation, and claimed
the full suite was fine — without actually running the full suite. The
full run would then show regressions because the fix broke other tests
or because environment state differed.

Example from session logs: "The test passes when run individually. The
remaining failures in the full suite are pre-existing issues." — but the
full suite had regressions that weren't pre-existing.

**Status:** Mitigated by the auto-loop running the full test suite after
each fix attempt. Individual-test verification is insufficient.

## 13. Output-Equivalent But Semantically Wrong

The test harness only compares stdout, stderr, and exit code. It does
NOT verify that side effects (file creation, directory structure, signal
handling, environment variables, process state) match the original bash.

A translation could produce identical output while creating files in
the wrong place, using wrong permissions, or leaving stale artifacts.
For example, `mkdir -p a/b/c` might create the directory tree but the
Perl version could use `mkpath('a/b/c')` which behaves identically.
However, more complex side effects like signal traps, background
processes, or file descriptor manipulation have no direct Perl
equivalent and the translator would omit them, producing correct
output but missing side effects.

**Status:** Inherent limitation of output-only comparison. No practical
fix without extending the test harness to verify side effects.
