# CLEAN_GIT — removing committed build artifacts and oversized blobs

**Status:** runbook. The workspace (`sh2loop`) cannot be pushed to GitHub
until its unpushed history stops carrying blobs over GitHub's 100 MB
limit. Nothing here has been committed to a remote yet.

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
index.

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
| `/home/llm/sh2loop` | `sh2loop` — `gh`=`gmatht/sh2loop`, `ai`, `hub`, `origin`=`/root/src/sh2loop` | `master` (328 commits ahead of `gh/master`=`1589f099`) | **needs cleaning** — 28 blobs >50 MiB, 3 >100 MiB, in `gh/master..master`; `.git` = 4.7 GB |
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

The oversized blobs live only in the unpushed range and are absent from
`HEAD`, so only that range needs rewriting. `--refs <range>` implies
`--partial`, which:

* rewrites only the range — the already-pushed base `1589f099` and its SHAs
  are untouched;
* **keeps the remotes** (`--partial` disables filter-repo's origin-removal
  and ref remapping).

```sh
cd /home/llm/sh2loop

# 0. safety: a ref OUTSIDE the rewritten range survives --partial
git branch backup/pre-filter master

# 1. dry run — writes only reports
git filter-repo --refs 1589f099..master \
  --path-glob 'log-archive/*' \
  --path-glob 'otranspilerl/target/*' \
  --path-glob '.shir-verify-target/*' \
  --invert-paths --dry-run --force

# 2. real run (drop --dry-run)
git filter-repo --refs 1589f099..master \
  --path-glob 'log-archive/*' \
  --path-glob 'otranspilerl/target/*' \
  --path-glob '.shir-verify-target/*' \
  --invert-paths --force

# 2b. alternative, size-based (clears the 50 MB warnings too)
#     git filter-repo --refs 1589f099..master --strip-blobs-bigger-than 50M --force

# 3. drop the stale local replace refs from the earlier partial run
git for-each-ref --format='%(refname)' refs/replace | xargs -r -n1 git update-ref -d

# 4. untrack the committed build dirs and commit (they are .gitignore'd now)
git rm -r --cached target 2>/dev/null || true
git add .gitignore
git commit -m "untrack the root target/ build dir; ignore cargo targets"

# 5. verify, then push
git --no-replace-objects rev-list --objects gh/master..master \
  | awk '{print $1}' | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize)' \
  | awk '$1=="blob" && $3>100000000'        # must print nothing
git push gh master
```

Notes / caveats:

* This rewrites the SHAs of the ~328 unpushed commits. They exist only
  locally, so that is fine; `backup/pre-filter` keeps the old tip.
* Commits that *only* added/updated artifacts may become empty and are
  pruned by filter-repo — expected.
* The tree is **shared with active workers**. Run the filter when they are
  quiesced, or accept `backup/pre-filter` as the safety net; a commit made
  mid-rewrite can race.
* `--refs <range>` needs the range base to be a commit that exists
  (`1589f099` = `gh/master`). If `gh` has advanced, re-read it with
  `git rev-parse gh/master`.
* The pushed remote history will have the filtered SHAs; that is a normal
  history rewrite for an unpushed range (no force-push of published
  commits is involved).

### sh2perl / frontends

No cleaning needed (no oversized blobs). If the sh2perl `merge-pr8` branch
is ever pushed, use the same pattern against `origin/main`
(`git rev-parse origin/main`).

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
