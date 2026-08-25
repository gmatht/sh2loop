# GIT_SIZE_CLEANUP.md — why the .git dirs were huge, what was done, what remains

Sizes before → after (2026-08-24):

| repo                  | before | after safe cleanup |
|-----------------------|--------|--------------------|
| `sh2loop/.git`        | 986 MB | **49 MB**          |
| `sh2loop/sh2perl/.git`| 668 MB | **387 MB**         |

## Root cause

Worker loops commit **build artifacts**, and every rebuild snapshots a fresh
multi-MB blob that barely delta-compresses:

- `frontends/c-sh-go/c-sh-go` — native Go binary, ~3.4 MB, committed ~38 times
  (~127 MB of history)
- `frontends/coverage/syn-coverage/target/debug/**` — Rust/Cargo build output
  (`libsyn*.rlib` 22 MB, `syn_coverage` binary 14 MB, rmeta/fingerprint files)
- `sh2perl/target-core/debug/**` — Cargo build dir committed wholesale
  (2612 files tracked at HEAD; ~1.7 GB of blob content across history)
- `frontends/*/*.wasm` — per-rebuild wasm builds (zsh 3.7 MB, perl 3.7 MB, …)
- `frontends/*/grammars/tree-sitter-*/src/parser.c` — GENERATED parser tables
  (powershell 10 MB, zsh 9.3 MB, zig 5.8 MB)
- stray logs: `.check_sh_files_run.log` (5.2 MB), `du-xh.log`, `.stash_history.log`
- `sh2perl/src/shir.rs` churn — large source, many full-text versions

## Done (safe — no history rewrite)

1. `.gitignore`s extended in both repos (see the "repo-size hygiene" blocks):
   `frontends/*/target*/`, `frontends/*/*.wasm`, tree-sitter `parser.c`,
   root logs; `target-core/` in sh2perl.
   NOTE: gitignore does NOT untrack files already in the index — see below.
2. Deleted `.git/lost-found/` in sh2loop (205 MB of dangling objects parked by
   an old `git fsck --lost-found`) and sh2perl's (1.8 MB), plus one garbage
   `tmp_obj_*`.
3. `git reflog expire --expire=now --all && git gc --prune=now` in both repos.
   In sh2loop this reclaimed ~940 MB — most of its bloat was *unreachable*
   loose objects from interrupted/repeated builds. fsck + status verified clean.

## Remaining to reach minimal size (DESTRUCTIVE — coordinate first)

### A. Untrack artifacts still in the index (safe-ish, but changes checkouts)

sh2perl (the big one, ~most of the remaining 387 MB pack is this path's history):
```sh
cd /home/llm/sh2loop/sh2perl
git rm -r -q --cached target-core && git commit -m "untrack target-core build dir"
```
sh2loop:
```sh
cd /home/llm/sh2loop
git rm -r -q --cached frontends/coverage/syn-coverage/target   # 206 files
git rm -q --cached frontends/*/[a-z]*.wasm                    # c/fish/go/perl/zsh builds
git rm -q --cached frontends/*/grammars/*/src/parser.c        # generated tables
git rm -q --cached .check_sh_files_run.log .stash_history.log du-xh.log
# REVIEW first: core-requests/transforms/verdicts.log may be intentional state
```
Workers rebuild these on demand (Makefile `test: build`), but any script that
reads them straight from a fresh clone needs a build step first — check with
the worker owners before committing.

### B. Rewrite history to reclaim already-committed bytes

Only worth it for sh2perl (379 MB pack). Requires `git filter-repo`, and it
rewrites EVERY commit hash — all backend worktrees under `sh2perl/backends/`
must be removed first and re-created afterwards (`setup_backends.sh`), running
workers stopped, and remotes force-pushed.

```sh
cd /home/llm/sh2loop/sh2perl
git filter-repo --force --invert-paths \
  --path target-core \
  --path-glob 'target*'
# optional extras: src/shir.rs churn cannot be removed without losing history;
# skip it — it compresses well relative to binaries
```
Expected recovery: roughly 300+ MB of the remaining pack.

For sh2loop (now only 49 MB) a rewrite is NOT worth the disruption.

## Going forward

The .gitignore additions stop NEW artifact commits. The existing
`.gitignore` policy ("built frontend binaries — build-on-test; never commit")
already covered the Go binaries; the leaks were the Cargo dirs, wasm builds,
generated parsers and logs — now covered too.
