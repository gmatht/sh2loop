# Why the per-tree board showed "NOT comparable: 8 skipped vs 7" on EVERY backend

**Date:** 2026-10-03. **Status:** root cause found and the corpus file restored.

## The symptom

Every backend row carried, simultaneously:

```
NOT comparable: 8 skipped vs 7 at the 4h mark (more files unmeasured)
```

`progress.sh` compares the newest gate row against the newest row at
least 4h old, and refuses to score the row if the two runs skipped a
different number of files. So one shared change to the skip count
blinded the whole board at once — c, fish, perl, rust, zsh, sh, all of them,
all at roughly 20:00–21:20.

## A skip is not a progress signal — it is a CORPUS signal

`setup_backends.sh:1507`:

```bash
if ! bash -n "$f" 2>/dev/null; then
  skip=$((skip+1)); continue
fi
```

A skip means **bash itself cannot parse the source file** — the
`parse-error-*` / `parse-unexpected-*` class. It is not an allowlist entry
(the gate reports "8 skip (0 allowlisted)") and not an emit failure (those
are counted as failures, deliberately, since a measurement that could not
be taken must not lower the fail count).

So `7 -> 8` means **one more corpus file became unparseable**.

## Root cause: a corpus file was overwritten with transpiler output

`sh2perl/examples/bc-native-capture.sh` had been clobbered with generated
Perl:

```perl
#!/usr/bin/env perl
...
die "otranspilerl: sh2.* call `unsupported` not yet supported by the shIR Perl backend\n";
```

`bash -n` rejects it (rc=2, "syntax error near unexpected token `$__i`"), so
it became the 8th skip. Its mtime was **2026-10-03 18:35** — the only one of
the eight that had changed; the other seven all date to 2026-08-24. The
correct bash source (a `bc` corpus test) is intact in git, so the file was
restored with `git checkout --`.

The damage was worse than a lost test: a real `bc` arithmetic test had been
silently removed from every backend's corpus at once.

## What did NOT cause it (measured, so nobody re-chases these)

- **Not the corpus growing.** The gate corpus is
  `examples/*.sh` + `frontends/*/testdata/*.sh` = 557 + 92 = 649. Only
  rust went to 650, later and separately; every other tree is still 649.
- **Not `progress.sh` picking the wrong baseline.** The board's conservatism
  is correct. A "find a scope-matched baseline" patch was written and
  reverted: the data shows no scope-matched baseline >=4h old exists for any
  tree, because the skip change is itself older than 4h.
- **Not the gate writing it.** The gate only ever calls
  `--target shir "$f"` and captures stdout into a variable; it never writes
  into `examples/`. The likeliest writer is an ad-hoc agent reproduction
  (`otranspiler <input> [<output>]` writes in place when the corpus path is
  passed as the output argument) — an agent action, not a gate bug.

## Other scratch in the corpus directory (harmless)

`examples/-`, `examples/__ps_tmp0`, `examples/__ps_tmp1` and 59
`examples/*.sig` files are generator scratch. None match the `examples/*.sh`
glob, so they are not in the gate corpus and do not affect any measurement.

## Verification

```
skips: 8 -> 7        (bash -n over examples/*.sh + frontends/*/testdata/*.sh)
examples/: git status clean
board:  fish clean; c 3f -> 1f; perl 336->335; zsh 45->44
```

Rows that still show `8 vs 7` simply have their last gate from before the
restore; the flag ages out as new gates land.

## Lesson

A corpus file is an INPUT. A tool that emits code must never be able to
write into the directory it reads. `otranspiler IN OUT` makes
`IN == OUT` a silent, destructive no-op, and the gate corpus lives next to
generated output. Worth an explicit `IN != OUT` refusal in the CLI.