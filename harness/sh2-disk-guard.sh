#!/bin/sh
# sh2-disk-guard.sh — disk high-water check for the sh2loop harness.
#
# WHY THIS EXISTS. The root filesystem on this box fills from MANY sources
# that no single process owns, and nothing anywhere checked free space:
#
#     /                 1007G total, 92% used as of 2026-09-29
#       /root           571G  (src/corro_mainloop 137G, opencode.db 31G, …)
#       /home/llm/sh2loop  66G (cargo target dirs, 557M loop logs, scratch)
#
# The harness's own share is the smaller half, so "the harness is big" is not
# the diagnosis — but a full disk is a silent, box-wide failure: cargo cannot
# link, the corpus gates fail for reasons unrelated to the transpiler, and
# git operations start failing. That is the same confident-wrong-answer
# failure the gate reports are written to avoid, and it is worth 15 lines of
# arithmetic to catch early.
#
# DELIBERATELY NON-DESTRUCTIVE. This reports. It does NOT delete anything.
# An automated reaper that deletes a git worktree, a cargo target dir, or a
# corpus example is a foot-gun that can destroy uncommitted work with no
# operator present, and the biggest consumers here (/root/src/*, 381G) are
# not the harness's to delete. Reporting at escalating thresholds buys the
# operator the time to decide, which is the only safe thing to automate.
#
# Exit codes are the systemd-visible signal:
#   0  below the warn threshold
#   0  above it, but reported (warning is not a failure — a full disk is an
#      operator decision, not a unit failure that should page/restart)
#   Deliberately never returns non-zero: a failing oneshot would show as
#      "failed" in `systemctl list-units` and mask the real condition behind
#      a service error.
#
# Env-tunable: SH2_DISK_PATH, SH2_DISK_WARN_PCT, SH2_DISK_CRIT_PCT
set -eu

PATH_="${SH2_DISK_PATH:-/}"

warn_pct="${SH2_DISK_WARN_PCT:-85}"
crit_pct="${SH2_DISK_CRIT_PCT:-92}"

# df -P forces POSIX output (one line, no wrapping) — without it a long
# device name wraps onto a second line and the awk field indices shift,
# which is exactly the kind of parse-in-the-dark this file exists to avoid.
line=$(df -P "$PATH_" 2>/dev/null | awk 'NR==2')
if [ -z "$line" ]; then
    echo "sh2-disk-guard: could not stat $PATH_ — skipping" >&2
    exit 0
fi

# POSIX df -P columns: Filesystem Blocks Used Available Capacity Mounted-on
pct=$(echo "$line"  | awk '{gsub(/%/,"",$5); print $5}')
avail=$(echo "$line" | awk '{print $4}')
total=$(echo "$line" | awk '{print $2}')
dev=$(echo "$line"   | awk '{print $1}')

# df -P reports in 1024-byte blocks, so the raw column is KiB, NOT bytes.
# Feeding 86894400 straight to numfmt printed "84MB" for what is really 83G
# — an available-space figure wrong by 1000x, which is worse than no figure
# at all. Scale to bytes first, then humanise.
human_avail=$(numfmt --to=iec --suffix=B $((avail * 1024)) 2>/dev/null || echo "${avail}K")
human_total=$(numfmt --to=iec --suffix=B $((total * 1024)) 2>/dev/null || echo "${total}K")

ts() { date +%FT%T; }

if [ "$pct" -ge "$crit_pct" ]; then
    echo "$(ts) CRITICAL disk: ${pct}% used on ${dev} (${human_avail} free of ${human_total}) — mount $PATH_"
    # The breakdown is EXPENSIVE and OPT-IN. A du -x over /root took 2m24s on
    # this box (381G of git worktrees) and blew a 60s timeout for /root and
    # /var while /home/llm finished. A timer that stalls for minutes is a
    # timer nobody enables, so the fast path reports the number and stops.
    # Set SH2_DISK_TRIAGE=1 to get the breakdown interactively.
    if [ "${SH2_DISK_TRIAGE:-0}" = "1" ]; then
        echo "  Largest consumers (does NOT delete anything):"
        for d in /root /home/llm /var /tmp; do
            [ -d "$d" ] || continue
            # -x stays on one filesystem; without it this walks into the 9p
            # /mnt/c drvfs share and HANGS for minutes (observed 2026-09-29).
            sz=$(timeout 45 du -shx "$d" 2>/dev/null | awk '{print $1}' || true)
            echo "    ${sz:-timed out}  $d"
        done
        echo "  Candidates: cargo target dirs, /root/src worktrees, log-archive, *.log.1, opencode.db."
    else
        echo "  (breakdown: re-run with SH2_DISK_TRIAGE=1 — a du -x here takes minutes)"
    fi
    echo "  ACTION REQUIRED by an operator: free space (nothing is removed automatically)."
elif [ "$pct" -ge "$warn_pct" ]; then
    echo "$(ts) WARNING disk: ${pct}% used on ${dev} (${human_avail} free of ${human_total}) — mount $PATH_"
    echo "  Above ${warn_pct}%. Run 'df -h /' and consider pruning before it reaches ${crit_pct}%."
else
    echo "$(ts) disk ok: ${pct}% used on ${dev} (${human_avail} free)"
fi

# Never fail the unit: a full disk is an operator decision, and a non-zero
# exit here would show as a failed service and mask the real message.
exit 0
