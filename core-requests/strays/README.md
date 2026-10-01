# Strays recovered from the shared core tree

Files that were sitting in `sh2perl/src/` but are **not** part of the shared
core (not declared in `src/lib.rs`, not present at `main-worktree` HEAD). They
are preserved here so no uncommitted work is lost, and removed from the core so
the tree stops reading as permanently dirty.

## zsh_backend.stray-20261001-1853.rs

- Origin: `sh2perl/src/zsh_backend.rs`, git state `DU` (unmerged index: stage 1
  base + stage 3 theirs, no stage 2). Its real home is the `backend/zsh`
  worktree (`backends/zsh/src/zsh_backend.rs`), which has a **newer** edit
  (2026-10-01 18:40, 6935 lines) than this stray (13:10, 5620 lines).
- Content hash: `1579f412bcc836e9a22fd60466f1044060011a51` (verified identical
  to the stage-3 index entry before removal).
- Recoverable from git until gc: `git cat-file -p 1579f412bcc836e9a22fd60466f1044060011a51`.
- It holds **122 lines** absent from the current worktree copy, so it is NOT
  proven fully superseded — hence preserved rather than deleted. Diff it against
  `backends/zsh/src/zsh_backend.rs` before discarding.
- Why it mattered: an unmerged index entry makes
  `git status --porcelain -- src/ Cargo.toml` non-empty **forever** (no commit
  can clear a `DU` entry without choosing a side). The backend workers gate on
  exactly that predicate being clean, so this one file parked the c, fish, rust
  and perl workers indefinitely with a bogus "core is unbuildable" reason —
  while the core in fact compiled clean in 60s.