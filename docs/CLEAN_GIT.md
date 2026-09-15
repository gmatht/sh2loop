# CLEAN_GIT — removing committed build artifacts and oversized blobs

**Status:** **done for `sh2loop`.** Full-history filtered and force-pushed
to `gh`; the repo went 4.7 GB → **19 MB**, the 28 oversized blobs and the
duplicated `frontends/` tree are gone, and `gh/master` is now `3319bad0`.
`sh2perl` and `otranspiler-frontends` need no cleaning (§4). The local
working clone (`/home/llm/sh2loop`) still carries the old objects and the
121 `refs/replace/*` from a partial attempt — re-sync it (§6c).

Related: `AGENTS.md` (submodule hygiene), `harness/c_gate_main.sh`, the
`.git/hooks/pre-commit` "pir guard".

---

## 1. The symptom

```
$ git push gh master            # from /home/llm/sh2loop
remote: error: File log-archive/loop-frontend-c-sh-go.log-20260819-031707.gz is 137.09 MB; this exceeds GitHub's file size limit of 100.00 MB
remote: error: File otranspilerl/target/debug/deps/libdebashl.rlib is 136.71 MB; this exceeds GitHub's file size limit of 100.00 MB
remote: error: File .shir-verify-target/debug/deps/libdebashl.rlib is 114.26 MB; this exceeds GitHub's file size limit of 100.00 MB
remote: error: GH001: Large files detected. You may want to try Git Large File Storage
 ! [remote rejected]   master -> master (pre-receive hook declined)
```

Only the `gh` push is affected; `ai`/`hub` (local mirrors) accept anything.
GitHub's threshold is a hard 100 MB per blob; it additionally *warns* above
50 MB.

---

## 2. Why the pre-commit hook did not stop it

The guard is real and installed:

* `.git/hooks/pre-commit` (identical copy in `sh2loop` and `sh2perl`),
  a `pir guard`: for every **staged** file (`git diff --cached --name-only
  --diff-filter=ACMR`) it refuses if the index blob is larger than
  `PIR_COMMIT_MAX_BYTES` (default **1 MiB**) or looks binary, and prints
  *"Use `git commit --no-verify` to override once"*.

It missed the artifacts for five independent reasons:

1. **It did not exist yet.** The hook is dated **2026-09-08 19:15**. The
   offending files entered in `40a8c389` — *"WIP snapshot (pre .git-only
   backup): worker-loop state, coverage updates, go-sh/c-sh-go frontend
   edits, gate reports"* — dated **2026-08-25**. They then propagated
   through merge commits `63747bf1` (2026-09-07) and `1bf2e6cc`
   (2026-09-13).
2. **`pre-commit` never runs on merge/pull/fetch/rebase/am/`fast-import`.**
   Merging an old branch re-introduces its objects with no size check at
   all. (Both offending commits are merges.)
3. **The guard is bypassable by design.** Its own message advertises
   `git commit --no-verify`; `PIR_COMMIT_MAX_BYTES` raises the cap; and
   bulk-import scripts use both. (`--no-verify` was in fact used for the
   1.9 MB `src/c_backend.rs` in this very session.)
4. **It only inspects the current repo's staged set.** Objects that arrive
   by `fetch`/`pull`, or that are created by `git filter-repo`/
   `git fast-import`, or that come from another clone
   (`origin` here is `/root/src/sh2loop`) are never checked.
5. **There is no `pre-push` hook.** The guard checks a file when it is
   *committed in this worktree*. What GitHub rejects is the **push set** —
   every object reachable from the pushed refs. Anything that slipped in
   earlier (points 1–4) stays in the push set forever, and the only
   backstop is GitHub's server-side 100 MB hook — the rejection above.

Worktrees (`sh2perl/backends/*`, `junk/backends/*`, `s2p.*`,
`/home/llm/sh2loop-dogfood`) share their parent's `.git/hooks` and object
store, so they are covered by the parent's guard — but commits made in a
*hook-less* clone are not, and a fetch imports them silently.

**Fix:** add a `pre-push` guard (see §7) that walks the *push set*, not the
index — `harness/pre-push-guard.sh`, now reachable as the tracked
`harness/git-hooks/pre-push`.

> **Update (same session):** the guard is no longer hand-installed and
> untracked.  `harness/git-hooks/{pre-commit,pre-push,install.sh}` are tracked,
> `install.sh` sets `core.hooksPath` for a clone, and `pre-push` is a shim over
> `harness/pre-push-guard.sh` (so redirecting `hooksPath` cannot silently
> disable it — which is exactly what the first version of this change did).
> Two additions since this analysis: the pre-commit guard now also refuses
> **merge-conflict markers in added lines** (the defect that reached `sh2perl`
> as a committed `>>>>>>>` marker), and `PIR_COMMIT_MAX_BYTES` is actually read
> — the old header advertised it but the script hardcoded 1 MiB.  Nothing under
> `frontends/` is checked: those files belong to another repository
> (`otranspiler-frontends`, mounted as `sh2perl/frontends`).

---

## 3. `.gitignore` state

Ignore rules stop *new* tracking only. Files already committed stay tracked
until `git rm --cached`, and objects in history are unaffected either way.

**`sh2loop/.gitignore`** (workspace):

| path | before | now |
|---|---|---|
| `/log-archive/` | ignored (added after the incident) | ignored |
| `/.shir-verify-target/` | ignored | ignored |
| `otranspilerl/target/` | ignored | ignored |
| `bash-o4/target/` | ignored | ignored |
| `/target/` (root cargo target) | **tracked, 265 MB / 505 files** | **ignored** |
| `target-core/` | not ignored | **ignored** |

**`sh2perl/.gitignore`**: `target/`, `target-core/` — already covered.
**`frontends`**: clean, nothing to ignore.

Still tracked at `HEAD` despite the rules (needs `git rm --cached`):

* the root `target/` — **505 files, 265 MB**, largest 15.7 MB
  (`target/debug/deps/libregex_automata-*.rlib`). Under GitHub's per-file
  limit, so not a push blocker, but every clone pays for it.
* `otranspilerl/target-core` (not ignored before this change).
* `.frontend_gate.tsv` — a generated 8.2 MB run-state report; consider
  ignoring it too.

Untrack:

```sh
git rm -r --cached target          # keeps the working files
git commit -m "untrack the root target/ build dir (now .gitignore'd)"
```

---

## 4. The trees that need cleaning

Three git repositories are reachable from the workspace. Cleaning is only
needed in the first.

| tree | repo / remote(s) | branch | status |
|---|---|---|---|
| `/home/llm/sh2loop` | `sh2loop` — `gh`=`gmatht/sh2loop`, `ai`, `hub`, `origin`=`/root/src/sh2loop` | `master` | **cleaned & pushed** — full-history filtered; `.git` 4.7 GB → 19 MB; 0 blobs >50 MiB; `frontends/` removed; `gh/master`=`3319bad0` (§6) |
| `/home/llm/sh2loop/sh2perl` | `sh2perl` submodule — `origin`=`gmatht/sh2perl` (default branch `main`), `ai`, `hub` | `merge-pr8` | **clean** — no blob >50 MB reachable; `.git` = 194 MB |
| `/home/llm/sh2loop/sh2perl/frontends` | `otranspiler-frontends` submodule — `origin`=`gmatht/otranspiler-frontends` | `master` | **clean, pushed** (`.git` = 4 KB — filtered history) |

### Worktrees (share a parent's object store; no separate cleaning)

* **`sh2perl` worktrees:** `sh2perl/backends/{c,core,java,js,python,rust,sh}`,
  `junk/backends/{go,perl,zig}`, `s2p.c`, `s2p.rust`, `s2p_go`, and the
  throwaway `/tmp/{sh2perl-isqrt,sh2perl-old,sh2perl-r2..r21,v3,bfix/head-check,f01,wt-prev}`.
  15 are `prunable` — clean up with
  `git -C sh2perl worktree prune`.
* **workspace worktrees:** `/home/llm/sh2loop-dogfood`
  (`dogfood/go-sh-value-channel`) — same object store as `sh2loop`.

Nothing else is a git repo: `otranspilerl/`, `bash-o4/`, `2c/`, `harness/`
are plain directories inside the `sh2loop` repo.

### The oversized blobs (workspace, original history)

`git --no-replace-objects rev-list --objects master` — everything is under
`log-archive/`, `otranspilerl/target/`, or `.shir-verify-target/`:

```
137.09 MiB  log-archive/loop-frontend-c-sh-go.log-20260819-031707.gz
136.71 MiB  otranspilerl/target/debug/deps/libdebashl.rlib
114.26 MiB  .shir-verify-target/debug/deps/libdebashl.rlib
 90.25 MiB  otranspilerl/target/debug/incremental/debashl-*/query-cache.bin
 88.76 MiB  otranspilerl/target/debug/incremental/debashl-*/query-cache.bin   (×2)
 88.51 MiB  otranspilerl/target/debug/incremental/debashl-*/query-cache.bin
 79.72 MiB  otranspilerl/target/debug/deps/libotranspilerl.so
 79.31 MiB  otranspilerl/target/debug/deps/otranspilerl_cli-*
 77.04 MiB  otranspilerl/target/debug/deps/otranspilerl_cli-*
 76.65 MiB  otranspilerl/target/debug/incremental/debashl-*/dep-graph.bin
 75.85 MiB  .shir-verify-target/debug/incremental/debashl-*/query-cache.bin
 …        (28 total; the pattern is `log-archive/`, `*/target/`, `.shir-verify-target/`)
```

The 143 MB `log-archive` blob was committed by `40a8c389` (2026-08-25); the
`libdebashl.rlib` pair by the same commit. All are absent from `HEAD`.

### A partial filter is already in place

`git replace -l` lists **121** `refs/replace/*` entries (all commit →
commit), i.e. a `git filter-repo --replace-refs` run has already rewritten
those commits *locally*:

* with replace refs (default `git rev-list`), the oversized blobs are
  **not** reachable from `master`;
* `git --no-replace-objects rev-list --objects master` still finds them.

So the branch refs still point at the original commits. **Do not assume the
push is clean because `git log`/`git rev-list` hide the blobs** — replace
refs are local UI sugar. Re-run the filter so the *refs* are rewritten
(§6), and clean up the leftover `refs/replace/*` afterwards.

---

## 5. The tool: `git filter-repo`, not `jj`

`jj` cannot do this: it has no path/glob history filter. `jj fix` rewrites
file **contents** in a revset but cannot delete files; `jj file untrack`
only affects the working copy. jj's own guidance for stripping paths/blobs
is "run `git filter-repo`, then let jj import the result".

`git-filter-repo` **2.38.0** is installed (`/usr/bin/git-filter-repo`).
After filtering, `jj git init --colocate` (or `jj git import`) picks up the
rewritten git history.

---

## 6. Procedure (workspace)

### 6a. Why the `--partial --refs` range filter is not enough

`git filter-repo --refs 1589f099..master --invert-paths …` rewrites only
the unpushed range and keeps the remotes and the pushed base — attractive,
but it **cannot drop a path that already exists in the base commit**.
`frontends/` is present in `1589f099`; the range's deletion of it is
filtered away like any other `frontends/` change, so the path is inherited
from the base and **reappears in the filtered tip** (1335 files). For
artifact *blobs* (absent from the base) the range filter is fine; to purge
a path that is in the published base you need a full rewrite.

### 6b. What was actually run (full history, in a clone)

`git filter-repo` needs a clean tree, and the workspace is shared with
active workers, so the rewrite was done in a throwaway **hardlinked
clone** and pushed from there:

```sh
git clone --local --no-checkout /home/llm/sh2loop /tmp/sh2loop-full
cd /tmp/sh2loop-full

git filter-repo \
  --invert-paths \
  --path-glob 'log-archive/*' \
  --path-glob 'target/*' \
  --path-glob 'otranspilerl/target/*' \
  --path-glob 'bash-o4/target/*' \
  --path-glob '.shir-verify-target/*' \
  --path-glob 'frontends/*' \
  --strip-blobs-bigger-than 50M \
  --force

# no --refs ⇒ the full history is rewritten; filter-repo drops `origin`
git remote add gh git@github.com:gmatht/sh2loop.git
git push --force gh master
```

Result:

| | before | after |
|---|---|---|
| `master` | `1589f099` (published) | `3319bad0` |
| `.git` | 4.7 GB | **19 MB** |
| blobs >50 MiB | 28 (3 >100 MiB) | **0** |
| `frontends/` at tip | 1335 files | **0** |
| commits | — | 1683 |

### 6c. Re-sync the local clone

A full rewrite changes every SHA, and the local working clone still holds
the old objects, the 121 `refs/replace/*` from the earlier partial attempt,
and **remote-tracking refs of the mirrors** that still point at the old
history (they keep the oversized blobs alive, so `gc` cannot prune them).
Re-clone (simplest), or, quiesced:

```sh
cd /home/llm/sh2loop
git for-each-ref --format='%(refname)' refs/replace | xargs -r -n1 git update-ref -d
git fetch gh master            # rewritten root: unrelated history
git reset --hard gh/master     # <-- discards uncommitted work; do it quiesced

# the ai/origin/hub tracking refs are caches of the OLD mirrors — drop them,
# or gc keeps the 137/136/114 MiB blobs alive. keep gh/master.
git for-each-ref --format='%(refname)' \
  refs/remotes/origin refs/remotes/ai refs/remotes/hub | xargs -r -n1 git update-ref -d

git reflog expire --expire=now --all
git reflog expire --expire=now --all --all-worktrees
git gc --prune=now
rm -rf .git/lost-found          # gc parks unreachable blobs here; ~1.6 GB
```

Measured for `sh2loop`: `.git` **4.7 GB → 136 MB**, `master` = `d6a483c2`.
A hard reset deletes the tracked `frontends/` and target copies; untracked
build dirs (`target/`) stay and are now `.gitignore`d. The linked worktree
`/home/llm/sh2loop-dogfood` and the `wip/*` branch keep their own (old)
history — rewrite or re-clone them separately if needed.

### sh2perl / frontends

No cleaning needed (no oversized blobs). If the sh2perl `merge-pr8` branch
is ever pushed, filter it the same way against `origin/main`.

---

## 7. Prevention

1. **Install a pre-push guard** — `harness/pre-push-guard.sh` (tracked):

   ```sh
   cp harness/pre-push-guard.sh .git/hooks/pre-push
   chmod +x .git/hooks/pre-push
   # repeat in sh2perl/.git/hooks/ (shared by its worktrees)
   ```

   It walks the objects actually being pushed
   (`git rev-list --objects <remote-sha>..<local-sha>`) and refuses any blob
   over 100 MB (GitHub's hard limit), warning above 50 MB. This closes the
   gap the `pre-commit` guard leaves: `--no-verify`, merges, fetches, and
   `filter-repo` output.

2. **Do not `git add -f` build artifacts**, and keep the root `target/`,
   `*/target/`, `target-core/`, `log-archive/`, `.shir-verify-target/`
   rules current.
3. **Untrack, don't just ignore.** A path added to `.gitignore` after being
   committed is still tracked (and pushed) forever until
   `git rm --cached`.
4. **Treat `--no-verify` as an event.** It is fine for a >1 MiB source file
   — commit it deliberately, and let the pre-push guard be the backstop.
5. **Audit periodically:**
   `git filter-repo --analyze` (writes `.git/filter-repo/analysis/`), or
   `git count-objects -vH` for overall size; `git worktree prune` for the
   stale worktrees listed in §4.
