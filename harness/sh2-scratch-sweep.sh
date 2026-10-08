#!/bin/sh
# sh2-scratch-sweep.sh — bound the size of the harness's per-run scratch
# directories, which are otherwise unbounded in BOTH age and size.
#
# WHY THIS EXISTS, alongside /usr/lib/sh2-tmp-sweep.
# sh2-tmp-sweep only removes entries matching `-name 'tmp.*'` older than 3
# days. That is deliberate and correct for the per-run mktemp trees, but it
# means the two directories that actually grew without bound are never
# touched at all, because their names do not match:
#
#     tmp_run/perl-gen-diffs/   harness/perl_gen_diffs.pl output
#     tmp_run/pg/               per-example generated-Perl scratch
#     tmp_run/t73dbg/           ad-hoc debug trees
#
# Measured 2026-09-29: tmp_run held 2.7 GB, of which 1.0 GB was a single
# `parse-error-block-in-pipeline.perl` and 940 MB its `.diff` — both the
# stdout of a translation that loops forever. Those files had been sitting
# since 05:07 and 05:27 that morning and were still there hours later,
# because a 3-day age threshold does not fire on a day-old runaway and the
# name filter would not have matched them even after 3 days.
#
# The cap in the gates (harness/cap-capture.pl) bounds what a SINGLE run can
# write. This bounds the ACCUMULATION across runs, which is the other half:
# 555 examples x 5 files each is a directory that only grows until someone
# deletes it.
#
# SAFETY RULES (deliberate, and deliberately conservative):
#   * Only the known scratch SUBDIRECTORIES are swept, never tmp_run itself
#     — it also holds real content (cmp_gate.sh, out.txt, docs).
#   * Only entries older than the age threshold go, so a run in progress
#     keeps its own files.
#   * A directory still in use (any process with it as cwd, or holding an
#     fd open) is SKIPPED entirely. Deleting a live gate's scratch fails the
#     gate in a far more confusing way than a missed cleanup.
#   * Report-only by default; --run to act. A mistyped threshold must not
#     delete anything from an interactive shell.
#   * Never returns non-zero: this is a janitor, and a failing oneshot
#     shows as a failed unit and masks the real condition.
#
# Env-tunable:
#   SH2_SCRATCH_DIRS   space-separated subdirs of tmp_run to bound
#   SH2_SCRATCH_AGE_H  minimum age of a file to remove, in hours (default 6)
set -u

ROOT=${SH2_TMP_RUN:-$(cd "$(dirname "$0")/.." && pwd)/tmp_run}
AGE_H=${SH2_SCRATCH_AGE_H:-6}
DIRS=${SH2_SCRATCH_DIRS:-"perl-gen-diffs pg"}

DRY_RUN=1
for arg in "$@"; do
    case "$arg" in
        --run) DRY_RUN=0 ;;
        --dry) DRY_RUN=1 ;;
        -h|--help)
            cat <<EOF
usage: sh2-scratch-sweep.sh [--run|--dry]

  --dry   (default) list what would be removed, delete nothing
  --run   actually remove stale files from the harness scratch dirs

env: SH2_SCRATCH_DIRS   subdirs to bound (default "$DIRS")
     SH2_SCRATCH_AGE_H  minimum age in hours (default $AGE_H)
EOF
            exit 0 ;;
    esac
done

[ -d "$ROOT" ] || { echo "sh2-scratch-sweep: $ROOT absent, nothing to do"; exit 0; }

# Is any process holding this path as its cwd, or holding an fd open to a
# file inside it? Read /proc directly — one pass, no per-pid fork.
in_use() {
    _p="$1"
    for _cwd in /proc/[0-9]*/cwd; do
        _t=$(readlink "$_cwd" 2>/dev/null) || continue
        case "$_t" in "$_p" | "$_p"/*) return 0 ;; esac
    done
    for _fd in /proc/[0-9]*/fd/*; do
        _t=$(readlink "$_fd" 2>/dev/null) || continue
        case "$_t" in "$_p"/*) return 0 ;; esac
    done
    return 1
}

# -mmin is minutes; the threshold is in hours and must be at least 1.
mmin=$(( AGE_H * 60 ))
[ "$mmin" -lt 1 ] && mmin=1

removed=0
freed=0

for name in $DIRS; do
    d="$ROOT/$name"
    [ -d "$d" ] || continue

    if in_use "$d"; then
        echo "sh2-scratch-sweep: $d in use — skipping"
        continue
    fi

    # Sum first so the report is honest about what a --run would free.
    sz=$(du -sk "$d" 2>/dev/null | awk '{print $1}')
    [ -n "$sz" ] || continue
    echo "sh2-scratch-sweep: $d is ${sz}K"
    [ "$sz" -gt 0 ] || continue

    # Only files, only stale ones, and never a subdirectory: a subdir could
    # be a live scratch tree that the name filter above did not catch.
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        s=$(stat -c %s "$f" 2>/dev/null) || continue
        [ -n "$s" ] || continue
        freed=$((freed + s))
        removed=$((removed + 1))
        if [ "$DRY_RUN" = "0" ]; then
            rm -f "$f" 2>/dev/null || true
        else
            echo "  would remove ${s}K $f"
        fi
    done <<EOF
$(find "$d" -maxdepth 1 -type f -mmin "+$mmin" 2>/dev/null)
EOF
done

if [ "$DRY_RUN" = "0" ]; then
    echo "sh2-scratch-sweep: removed $removed stale files, $((freed / 1024))K freed"
else
    echo "sh2-scratch-sweep: (dry run) $removed stale files, $((freed / 1024))K reclaimable — re-run with --run"
fi

# Never fail the unit.
exit 0
