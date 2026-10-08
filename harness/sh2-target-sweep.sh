#!/bin/sh
# sh2-target-sweep.sh — bound the size of the per-worktree cargo target
# directories, which are otherwise unbounded in both age and size.
#
# WHY THIS EXISTS, alongside sh2-scratch-sweep.sh.
# That sweep bounds the harness's SCRATCH dirs (tmp_run/perl-gen-diffs,
# tmp_run/pg). It does not touch target/, which is where nearly all of the
# harness's disk actually is.
#
# Measured 2026-09-30: 43 GB across 11 worktrees, on a 1007 GB root at
# 96-97% used, with sh2-disk-guard reporting CRITICAL. The breakdown per
# worktree (c: 13 G, rust: 10 G, java 4.3 G, sh 4.0 G, perl 2.9 G, js
# 2.5 G, fish 1.9 G, core 1.7 G, zsh 1.7 G, zig 963 M, python 997 M) is
# dominated by target/debug/{deps,incremental}.
#
# WHY A TMPFS WAS CONSIDERED AND REJECTED
# ---------------------------------------
# Moving target/ to tmpfs is the obvious way to free that space and it is
# wrong here, for three measured reasons. Do not reintroduce it without
# re-measuring:
#
#   1. IT IS A SPACE PROBLEM, NOT AN IO PROBLEM. A forced rebuild of
#      shir_render (touch src/estree.rs, then build) wrote 587 MB in 30 s
#      (29 MB/s) in sh2workers, while init.scope wrote 1577 MB in the same
#      window. With nothing of ours building, BOTH cgroups measure 0.0 MB/s.
#      A build is a 30-second burst, then silence — there is no sustained IO
#      to remove. (It also confirms the 32 MB/s io.max ceiling never fires:
#      29 MB/s is under it, so nr_throttled=0 is the expected reading.)
#   2. IT DOES NOT FIT. The five live worktree targets total 31.8 GB and the
#      shared sh2perl/target another 6.2 GB = 38.0 GB, against 40.6 GB
#      MemAvailable. That is ~94% of RAM, and tmpfs pages are unevictable:
#      sh2workers memory.high is 8 GB, so memory.reclaim could take nothing
#      back and the ceiling would become a hard OOM. That is precisely the
#      wedge sh2-memory-reclaim.sh exists to prevent.
#   3. SEEDING FROM sh2perl/target DOES NOT RECOVER IT. The shared dir and a
#      worktree overlap by 326 filenames / 2.15 GB — the third-party crates
#      (of c's 7.0 GB deps, only 2.7 GB is debashl's own artifacts). The
#      per-worktree part that must be reproduced is exactly the part that
#      cannot be seeded, because src/ diverges per worktree (31 files in c
#      vs main), so libdebashl.rlib, shir_render and each *_backend differ
#      (c=a1031dbd vs rust=270b9ec2 for libdebashl.rlib).
#
# WHAT IS SAFE TO DELETE, AND WHY
# -------------------------------
# Only target/debug/incremental, and only in a worktree with no live
# worker. Reasons, in order of importance:
#
#   * incremental/ is a pure CACHE. Cargo regenerates it on the next build;
#     nothing reads it except rustc's own dep-graph reuse. Deleting it
#     costs one slower rebuild and cannot change any binary's contents.
#     Measured cost, in a throwaway target dir: COLD build 127 s (producing
#     1007 MB), WARM one-file rebuild 23 s, NO-OP 16 s. So the worst case
#     is ~104 s of extra rebuild, ONCE per worktree.
#   * deps/ is NOT swept. It holds the rlib/binaries a gate execs, and it
#     is the expensive part to rebuild.
#   * The five LIVE worktrees are never swept. Their incremental/ is where
#     the 5-minute build loop actually pays for itself, and a cold build
#     inside a gate holds the box-wide .gate.lock (setup_backends.sh:708)
#     for over two minutes — so one worker's clean would stall all of them.
#
# THE INVARIANT THIS MUST NOT BREAK
# ---------------------------------
# setup_backends.sh:1314 records, deliberately: "There is also no `cargo
# clean` anywhere that removes this binary." The gate execs shir_render out
# of the worktree target, and a blanket `cargo clean` that deleted it would
# turn a live gate run into an unexplained rc=127. Hence: incremental/ only,
# never deps/, never the bins, never a dir a live process is holding.
#
# SAFETY RULES (mirroring sh2-scratch-sweep.sh, deliberately conservative):
#   * Only target/debug/incremental under a worktree, never target/ itself
#     and never any other subdir.
#   * Only worktrees with NO live --run-backend-worker process.
#   * Only worktrees whose incremental/ has no file newer than the age
#     threshold (default 24 h), so an in-flight edit cycle keeps its cache.
#   * A directory still in use — any process with it as cwd, or holding an
#     fd open inside it — is SKIPPED entirely. Missing a cleanup is far
#     cheaper than deleting a live build's working set.
#   * ONE /proc scan for all candidates. A full fd scan of ~500 pids costs
#     ~12.7 s here, so a scan per candidate would cost 9x that for no gain.
#   * Report-only by default; --run to act.
#   * Never returns non-zero: this is a janitor, and a failing oneshot shows
#     as a failed unit and masks the real condition.
#
# Env-tunable:
#   SH2_TARGET_AGE_H    minimum incremental/ age to sweep, hours (default 24)
#   SH2_TARGET_WORKSPACE  harness root (default: this script's repo root,
#                         derived from $0 — do not hardcode a path here, the
#                         workspace moves; see the 2026-10-08 move to
#                         /mnt/wsl/projects/sh2loop)
#   SH2_TARGET_MIN_MB   only report/sweep dirs at least this big, MB
#                       (default 256; below this the rebuild is not worth
#                       the risk of touching a live worktree's cache)
set -u

WS=${SH2_TARGET_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}
AGE_H=${SH2_TARGET_AGE_H:-24}
MIN_MB=${SH2_TARGET_MIN_MB:-256}
# Incremental-only: never widen this to deps/ or target/ itself. See the
# invariant note above.
SUBPATHS="target/debug/incremental"

DRY_RUN=1
for arg in "$@"; do
    case "$arg" in
        --run) DRY_RUN=0 ;;
        --dry) DRY_RUN=1 ;;
        -h|--help)
            cat <<EOF
usage: sh2-target-sweep.sh [--run|--dry]

  --dry   (default) list what would be removed, delete nothing
  --run   actually remove stale incremental/ dirs

env: SH2_TARGET_AGE_H    minimum age in hours (default $AGE_H)
     SH2_TARGET_MIN_MB   minimum dir size in MB (default $MIN_MB)
     SH2_TARGET_WORKSPACE  harness root (default $WS)

Only target/debug/incremental is ever touched. deps/ and the built binaries
are never removed: the gates exec them.
EOF
            exit 0 ;;
    esac
done

SUB="$WS/sh2perl"
[ -d "$SUB/backends" ] || { echo "sh2-target-sweep: $SUB/backends absent, nothing to do"; exit 0; }

# ── ONE /proc scan for every candidate ─────────────────────────────────
# Collect every path any process holds (as cwd or as an open fd) into a
# file, then match candidates against it. Read /proc directly: one pass,
# no per-pid fork. ~12.7s for ~500 pids here, versus 12.7s PER candidate.
HELD=$(mktemp) || { echo "sh2-target-sweep: cannot create temp file, nothing to do"; exit 0; }
trap 'rm -f "$HELD"' EXIT INT TERM
for _cwd in /proc/[0-9]*/cwd; do
    readlink "$_cwd" 2>/dev/null
done >> "$HELD" 2>/dev/null
for _fd in /proc/[0-9]*/fd/*; do
    readlink "$_fd" 2>/dev/null
done >> "$HELD" 2>/dev/null

# Is any path at or under $1 held by a live process?
in_use() {
    _p="$1"
    grep -q -e "^$_p\$" -e "^$_p/" "$HELD" 2>/dev/null
}

# Does a live --run-backend-worker own this worktree? A worktree with a
# live worker keeps its cache: it is actively paying for it.
worker_live() {
    ps -eo args 2>/dev/null \
        | grep -q -- "--run-backend-worker $(basename "$1")\$"
}

mmin=$(( AGE_H * 60 ))
[ "$mmin" -lt 1 ] && mmin=1

removed=0
freed_mb=0
skipped_live=0
skipped_held=0
skipped_small=0
skipped_fresh=0

for d in "$SUB"/backends/*/"$SUBPATHS"; do
    [ -d "$d" ] || continue
    wt=$(dirname "$(dirname "$(dirname "$d")")")

    # Size first, so a small dir costs nothing to skip and the report is
    # honest about what a --run would actually free.
    sz_mb=$(du -sm "$d" 2>/dev/null | awk '{print $1}')
    [ -n "$sz_mb" ] || continue

    if [ "$sz_mb" -lt "$MIN_MB" ]; then
        echo "sh2-target-sweep: $wt (${sz_mb}M) below ${MIN_MB}M — skipping"
        skipped_small=$((skipped_small + 1))
        continue
    fi

    if worker_live "$wt"; then
        echo "sh2-target-sweep: $wt has a LIVE worker — skipping"
        skipped_live=$((skipped_live + 1))
        continue
    fi

    if in_use "$d"; then
        echo "sh2-target-sweep: $d held by a live process — skipping"
        skipped_held=$((skipped_held + 1))
        continue
    fi

    # Freshness: any file newer than the threshold means an edit cycle is
    # using this cache. One -newermt probe is far cheaper than walking the
    # whole tree (873 files in core/, walked in 7 ms, but that is per-dir).
    if [ -n "$(find "$d" -type f -mmin "-$mmin" -print -quit 2>/dev/null)" ]; then
        echo "sh2-target-sweep: $wt (${sz_mb}M) has files newer than ${AGE_H}h — skipping"
        skipped_fresh=$((skipped_fresh + 1))
        continue
    fi

    freed_mb=$((freed_mb + sz_mb))
    removed=$((removed + 1))
    if [ "$DRY_RUN" = "0" ]; then
        rm -rf "$d" 2>/dev/null || { echo "  rm failed: $d"; continue; }
        echo "sh2-target-sweep: removed $d (${sz_mb}M)"
    else
        echo "  would remove $d (${sz_mb}M)"
    fi
done

if [ "$DRY_RUN" = "0" ]; then
    echo "sh2-target-sweep: swept $removed incremental dirs, ${freed_mb}M freed"
else
    echo "sh2-target-sweep: (dry run) $removed dirs, ${freed_mb}M reclaimable — re-run with --run"
fi
echo "sh2-target-sweep: skipped: $skipped_live live-worker, $skipped_held held, $skipped_small small, $skipped_fresh fresh"

# Never fail the unit.
exit 0