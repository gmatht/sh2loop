# Splitting the `-O4` driver family into its own GPL-3 repository

**Status:** plan. Nothing here has been applied to the live trees. `harness/split-off-o4.sh`
builds the whole thing in a scratch directory and never pushes without `--push`.

**It is a SPLIT, not a fork.** `bash-o4`, `otranspilerl` and `frontends/` exist *only* in
sh2loop — there is no upstream to fork them from. `sh2perl` is the only component with an
upstream, and it is consumed as a submodule. The frontends are likewise given their own
repo (`otranspiler-frontends`, decision D3) rather than being copied around.

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
├── frontends/             <- SUBMODULE: otranspiler-frontends (D3)
├── docs/                  <- BASH-O4.md, BASH_VULKAN.md, PYTHON-O4.md, ...
├── harness/               <- c_gate_main.sh, gpu_gate.sh (ROOT made $0-relative)
└── tests/release-check.sh <- self-verification written by the split
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

**D1 — Licence: GPL-3 only, and *never* copy `sh2perl/LICENSE`.**  The two files in
sh2perl are not a pair to be copied together:

| file | what it is |
|---|---|
| `sh2perl/LICENSE.GPL3` | the **GNU GPL v3 licence text** — what a derived work is conveyed under |
| `sh2perl/LICENSE` | a **personal grant**: "GPL-3.  ADDITIONALLY, recipients … that I, John Christopher McCabe-Dansted, have sent or linked this software to during paid work … may additionally distribute … under Apache-2.0" |

`sh2perl/LICENSE` is keyed to named relationships and specific recipients; it is
not a general licence for the public and must not be republished as though it
were this repo's.  So the script copies **`LICENSE.GPL3` → `LICENSE`** (root and
`bash-o4/`), sets `license = "GPL-3.0-only"` + `license-file = "LICENSE"`, and
copies `sh2perl/LICENSE` **nowhere**.  It also greps the result for
`ADDITIONALLY|McCabe-Dansted|Apache-2.0` and refuses to continue if that text
arrived by any route.

(A consequence worth stating: dropping the additional permission means GPL-3 has
a single SPDX id, so the fork's metadata can be exact — `GPL-3.0-only` rather
than the `license-file`-only arrangement the source tree needed.)

**D2 — History.** Default: preserve it, using `git filter-repo --path bash-o4/
--path otranspilerl/` and grafting with `--allow-unrelated-histories`, exactly
as `harness/migrate-frontends-to-sh2perl.sh` does. SHAs are rewritten, so the
script emits `commit-map` + `MOVE.md` for provenance. `--snapshot` is the fast
alternative (one squashed "release snapshot" commit) for when provenance does
not matter; the full-history path is not exercised by the self-test because
filter-repo rewrites a 4.7 GB repo.

**D3 — Frontends get their own repo: `otranspiler-frontends`.**  Verified facts:
`frontends/` is **not** in sh2perl (0 commits on any ref, and no `frontends/` in
its worktree); it is 1392 tracked files living in sh2loop, actively developed
there, and it has **no remote of its own**.  `harness/migrate-frontends-to-sh2perl.sh`
is an **unapplied proposal**, not history.  So there is nothing to point a
submodule at — until we make one.

Therefore the split-off *produces* it: `frontends/` is split into its own
repository named **`otranspiler-frontends`** (same `git filter-repo --path
frontends/` machinery, history preserved), and the `-O4` repo consumes it as a
**submodule at `frontends/`**.  That keeps `find_frontend()` working unchanged
(it looks for `<root>/frontends/py-sh-go/py-sh-go`, where `<root>` is the
directory containing `sh2perl`), and `$PY_SH_GO` still overrides it.

Ordering matters: the frontends repo must exist before the `-O4` repo can
submodule it.  Run `--frontends-only`, push that repo, then run the main path
with `--frontends-remote <url>`.  Alternatively `--frontends-src <path>` consumes
a local checkout directly.  `--vendor-frontend` still exists as a deprecated
fallback (a plain copy that *will* go stale) and `--no-frontend` omits it, in
which case `python-O4` needs `$PY_SH_GO`.

**D4 — Where they live.**  The script never creates or infers a repository: `--name`
(default `o4`) is a **local directory** name and `--remote` is explicit, because a
wrong URL pushed once is a mess.  It *prints* a suggestion with the owner derived
from the sh2perl remote (`git@github.com:gmatht/sh2perl.git` → `gmatht`), and
`--gh-org` overrides it.  Two repos are in play: **`otranspiler-frontends`**
(D3, push first) and the `-O4` driver repo (default local name `o4` — a name that
covers the whole family, since it holds `bash-O4`, `python-O4` and
`otranspilerl`; `bash-o4` would misdescribe it).

**D5 — Direction of flow (important).** The repo is a **release mirror**, not a
second development branch: development stays in `sh2loop`, and a release is cut
by re-running this script at a chosen ref. Two-way edits would drift and there
is no merge story. The script therefore pins the base refs in `base.env` (so a
resumed run cannot half-rebase) and records them in `MOVE.md`. If development
should instead move *into* `o4/`, that is a follow-up migration (the same
filter-repo direction) and should be planned separately.

**D6 — What stays behind.** `./fail` (the Perl corpus gate, ESTree/Perl
workstream), `fail-coreutils`, `harness/estree-*`, the `corro`/`s2p_*`
worktrees, and every tracked scratch state file (`.gate.lock`, `.estree_*`, `.shir_*`, `.pir/`). The `-O4` gates are
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
   `CHANGELOG.md`, the release `docs/` and `harness/{c_gate_main.sh,gpu_gate.sh}`.
3b. **Frontends** — split `frontends/` into the `otranspiler-frontends` repo
   (`--frontends-only` stops here so it can be pushed first), then consume it as
   a submodule at `frontends/`.
4. **Submodule** — `git submodule add <sh2perl-url> sh2perl`, then check out the
   frozen gitlink SHA (the local submodule may carry commits not yet pushed,
   so it is cloned from the local checkout and `origin` is re-pointed).
5. **Licence** — copy `sh2perl/LICENSE.GPL3` to `LICENSE` and `bash-o4/LICENSE`
   (GPL-3 text only); set `license = "GPL-3.0-only"` + `license-file`; refuse if
   `sh2perl/LICENSE`'s personal-grant wording appears.  `sh2perl/LICENSE` is
   copied nowhere.
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

## 7. Self-containment: three artifacts are built, not tracked

Found while verifying the split-off end-to-end — each one silently changes the
gate result, so the repo is **not** self-contained until they are addressed:

| prerequisite | without it | remedy |
|---|---|---|
| `cargo build --bin otranspilerl-cli` | `c_gate_main.sh` SKIPs **all 644** files (`PASS=0 FAIL=0 SKIP=644`) — the gate shells out to that binary | documented in the fork's README + `release-check.sh` builds it |
| `make -C frontends/py-sh-go` | `python-O4` cannot locate its frontend; the binary is **gitignored upstream** (frontends/.gitignore: build-on-test) | documented + built by `release-check.sh`; `$PY_SH_GO` overrides |
| `bash sh2perl/runtime/build_uu_ffi.sh` | the gates link `runtime/lib/libcoreutils_ffi.so`; without it **30 examples fail** (`cpu=1`, every uu-ffi builtin: `test`, `uname`, `sleep`, …) | documented + built by `release-check.sh` |

The third is the real finding: `sh2perl/runtime/lib/` has **0 tracked files**, and
`build_uu_ffi.sh` builds from an **out-of-tree** crate
(`/root/src/coreutils/uu-ffi`, overridable via `$UU_FFI_DIR`) with **no pin
recorded anywhere in sh2loop or sh2perl**. So a clone of the release repo cannot
reproduce the gates without fetching that crate at an unpinned revision — which
is exactly the "unpinned upstream is refused" rule this project applies
elsewhere. Options for the owner:

1. pin uu-ffi properly (its own repo/submodule, or a hash-pinned fetch like
   `bash-o4-manifest.toml` already does for volk/glslang);
2. make the uu-ffi path optional in the C backend (fall back to fork/exec), so a
   release can build and gate without it;
3. accept it as an external prerequisite and record the pin by hand in
   `MOVE.md`.

## 8. Open items for the owner

- **Confirm the licence** (D1) — the only decision with legal weight.
- **Pick the remote** (D4) and whether `o4` is the right name.
- **Decide the frontend's long-term home** (D3) once the frontends→sh2perl
  migration lands.
- **Decide whether the fork ever becomes the development home** (D5); if yes,
  plan the reverse migration explicitly.
- The fork still cannot be `cargo publish`-ed (path dependencies) and `tcc`
  remains an unvendored runtime dependency. Both are already recorded in
  `CHANGELOG.md` → "Open release decisions".
