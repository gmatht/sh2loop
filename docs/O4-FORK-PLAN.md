# Forking the `-O4` driver family into its own GPL-3 repository

**Status:** plan. Nothing here has been applied to the live trees. `harness/fork-o4.sh`
builds the whole thing in a scratch directory and never pushes without `--push`.

## 1. Why

The `-O4` driver family (`bash-O4`, `python-O4`) currently lives inside the
`sh2loop` **development workspace**, which is a poor release vehicle:

- **Licensing is entangled and undeclared.** `bash-o4` links `sh2perl`, whose
  `LICENSE` is GPL-3 **plus an additional Apache-2.0 permission** for named
  paid-work recipients and their subrecipients. That is a derivative work, so
  the driver cannot be MIT/Apache — yet the workspace declares no licence at
  all, which is why `bash-o4/Cargo.toml` deliberately carries no `license` key.
- **The workspace is full of other workstreams and scratch state**: the
  ESTree/Perl migration (`./fail`, `.estree_*`, `.perl_*`), `corro`/`s2p_*`
  worktrees, `.gate.lock`, `.pir/`, triage logs. None of it belongs in a
  released artifact, and it makes "what is the `-O4` release?" unanswerable.
- **`otranspilerl` and `bash-o4` are plain directories in that workspace**, so
  they cannot be cloned, tagged or versioned on their own.

Splitting them out gives a repo that is *exactly* the release: the driver, its
frontend dependency, its corpus and gates, and `sh2perl` pinned as a GPL-3
submodule.

## 2. Target topology

```
o4/                        <- new repo, GPL-3 (inherits sh2perl's terms)
├── .gitmodules            <- sh2perl @ pinned SHA
├── LICENSE                <- verbatim copy of sh2perl/LICENSE  (not authored here)
├── README.md              <- from bash-o4/README.md
├── CHANGELOG.md
├── bash-o4/               <- from sh2loop/bash-o4      (history preserved)
│   ├── bench/             <- both bench drivers + corpus (sh/, c/, py/)
│   ├── examples/          <- cutranspile, cudabench, gpuleg, vkbench, vkprobe...
│   ├── src/  tests/
│   └── LICENSE            <- copy of ../LICENSE, so `license-file` is in-package
├── otranspilerl/          <- from sh2loop/otranspilerl  (history preserved)
├── sh2perl/               <- SUBMODULE, pinned to the workspace gitlink SHA
├── frontends/py-sh-go/    <- python-O4's frontend (see decision D3)
├── docs/                  <- BASH-O4.md, BASH_VULKAN.md, PYTHON-O4.md, ...
├── harness/               <- c_gate_main.sh, gpu_gate.sh (ROOT made $0-relative)
└── tests/fork-check.sh    <- self-verification written by the fork
```

**This layout is chosen so that no source file changes.** Every path dependency
already resolves against it:

| crate | dependency | resolves to |
|---|---|---|
| `bash-o4` | `../otranspilerl` | `o4/otranspilerl` ✓ |
| `bash-o4` | `../sh2perl` | `o4/sh2perl` (submodule) ✓ |
| `otranspilerl` | `../sh2perl` | `o4/sh2perl` ✓ |

`bash-o4/build.rs` also keeps working untouched: it hashes the git state of
`..` and `../sh2perl`, i.e. the new repo's HEAD and the submodule — so the
content-addressed cache revision still changes with uncommitted edits.

`python-O4`'s `find_frontend()` searches `<root>/frontends/py-sh-go/py-sh-go`
where `<root>` is the directory containing `sh2perl`, so `o4/frontends/…` is
found with no change; `$PY_SH_GO` remains the override.

## 3. Decisions (each with a recommendation)

**D1 — Licence.** The fork is a derivative of GPL-3 `sh2perl`, so it is
distributed under GPL-3 *with* sh2perl's additional Apache-2.0 permission.
The script **copies `sh2perl/LICENSE` verbatim** to `o4/LICENSE` and
`o4/bash-o4/LICENSE` and sets `license-file = "LICENSE"` in `bash-o4/Cargo.toml`
(SPDX has no id for "GPL-3 plus an extra permission", so `license-file` is the
accurate key). It **refuses** if `sh2perl/LICENSE` is missing rather than
inventing text. *The owner should confirm this is the intended distribution;
that is a legal call, not a mechanical one.*

**D2 — History.** Default: preserve it, using `git filter-repo --path bash-o4/
--path otranspilerl/` and grafting with `--allow-unrelated-histories`, exactly
as `harness/migrate-frontends-to-sh2perl.sh` does. SHAs are rewritten, so the
script emits `commit-map` + `MOVE.md` for provenance. `--snapshot` is the fast
alternative (one squashed "release snapshot" commit) for when provenance does
not matter; the full-history path is not exercised by the self-test because
filter-repo rewrites a 4.7 GB repo.

**D3 — The Python frontend.** `frontends/py-sh-go/` is a plain directory in the
workspace, and `python-O4` needs its binary. Recommendation: **include it in
the fork now** (it is small — 328 MB on disk, mostly build output), and follow
the in-flight `migrate-frontends-to-sh2perl.sh` work later: once frontends live
in `sh2perl/frontends/`, this fork should point at the submodule copy and drop
the vendored one. `$PY_SH_GO` is the escape hatch in the meantime, so the
script also writes a `frontend-refs.txt` noting the coupling.

**D4 — Where it lives.** The script cannot invent a remote. Default: create a
**local bare repo** inside the work dir (`--bare $WORK/o4.git`) for review.
`--remote URL` sets the real remote; `--push` is the only live action.

**D5 — Direction of flow (important).** The fork is a **release mirror**, not a
second development branch: development stays in `sh2loop`, and a release is cut
by re-running this script at a chosen ref. Two-way edits would drift and there
is no merge story. The script therefore pins the base refs in `base.env` (so a
resumed run cannot half-rebase) and records them in `MOVE.md`. If development
should instead move *into* `o4/`, that is a follow-up migration (the same
filter-repo direction) and should be planned separately.

**D6 — What stays behind.** `./fail` (the Perl corpus gate, ESTree/Perl
workstream), `fail-coreutils`, `harness/estree-*`, the `corro`/`s2p_*`
worktrees, `frontends/` other than `py-sh-go`, and every tracked scratch state
file (`.gate.lock`, `.estree_*`, `.shir_*`, `.pir/`). The `-O4` gates are
`c_gate_main.sh` (637/0/7) and `gpu_gate.sh` (545/0/7) — those are what the
fork must keep green.

**D7 — Release hygiene already done, to carry over.** `--gpu` dispatch and the
shared `flags.rs` surface, the `fuse-fill-consume`/`isolate-accumulate`
transforms, 0 crate warnings, `SH2_DEBUG_PARSER`-gated parser traces, and the
SIGPIPE fix. The fork inherits all of it; `tests/fork-check.sh` re-verifies it.

## 4. Steps the script performs

1. **Preflight** — `git-filter-repo` present, `sh2perl` initialised, the
   extracted paths clean (or `--allow-dirty-*`), base refs frozen in
   `base.env`.
2. **Extract** — clone `sh2loop` at the frozen ref, `filter-repo --path
   bash-o4/ --path otranspilerl/` (or `--snapshot`).
3. **Assemble** — init the new repo, fetch the extract, copy `README.md`,
   `CHANGELOG.md`, the release `docs/`, `harness/{c_gate_main.sh,gpu_gate.sh}`,
   and `frontends/py-sh-go`.
4. **Submodule** — `git submodule add <sh2perl-url> sh2perl`, then check out the
   frozen gitlink SHA (the local submodule may carry commits not yet pushed,
   so it is cloned from the local checkout and `origin` is re-pointed).
5. **Licence** — copy `sh2perl/LICENSE` verbatim to `LICENSE` and
   `bash-o4/LICENSE`; add `license-file` to `bash-o4/Cargo.toml`; fail loudly
   if the source licence is missing.
6. **Repath** — rewrite the hardcoded `ROOT=/home/llm/sh2loop` in the two gate
   scripts to derive `ROOT` from `$0` (the only source edits the fork needs),
   and prove it by grepping for any surviving absolute workspace path.
7. **Self-verification** — write `tests/fork-check.sh`.
8. **Provenance** — `MOVE.md`, `commit-map`, `frontend-refs.txt`,
   `human-decisions.txt`.
9. **Report** — the review/rollout commands, and *nothing pushed* unless
   `--push` was given.

## 5. Verification

`tests/fork-check.sh` (runs inside the new repo, no network once submodules are
present):

1. `cargo build --offline --bins` → both binaries exist.
2. `cargo test --offline` → 0 failures (excludes the `sh2perl` lib suite, which
   is the core's own).
3. `cargo build --offline --lib --message-format=short` → no warnings from
   `bash-o4`'s own sources.
4. `bash harness/c_gate_main.sh` → `FAIL=0`.
5. `bash harness/gpu_gate.sh` → `FAIL=0` (skips loudly with no CUDA device).
6. `bash-O4 --check` on the bench shape reports a CUDA candidate, and
   `bash-O4 --gpu --n …` agrees with bash's stdout.
7. `grep -rn '/home/llm/sh2loop'` over the tree → no hits.
8. `git submodule status` → `sh2perl` at the pinned SHA, not `-dirty`.

Run it as the last gate before tagging.

## 6. Rollback

Nothing outside the scratch work dir changes until **`--push`**, and that is one
`git push` of a new branch/repo. The live `sh2loop` and `sh2perl` trees are only
ever read. Dropping the work dir loses nothing committed upstream.

## 7. Open items for the owner

- **Confirm the licence** (D1) — the only decision with legal weight.
- **Pick the remote** (D4) and whether `o4` is the right name.
- **Decide the frontend's long-term home** (D3) once the frontends→sh2perl
  migration lands.
- **Decide whether the fork ever becomes the development home** (D5); if yes,
  plan the reverse migration explicitly.
- The fork still cannot be `cargo publish`-ed (path dependencies) and `tcc`
  remains an unvendored runtime dependency. Both are already recorded in
  `CHANGELOG.md` → "Open release decisions".
