#!/bin/sh
# sh2-contain.sh — close the init.scope IO loophole.
#
# THE BUG (measured 2026-09-29). The fleet's throttles are all real and all
# working: sh2-io.slice, sh2workers and sh2gates each carry
#
#     8:48 rbps=max wbps=33554432 riops=max wiops=2000
#
# and those cgroups hold 20 / 295 / 15 processes respectively. But
# /init.scope — the cgroup every process lands in by DEFAULT under WSL2 —
# has an EMPTY io.max. Summing write_bytes per process and bucketing by the
# cgroup each writer was actually in at the time:
#
#     writers inside a capped cgroup:  186 GB
#     writers inside init.scope:     1106 GB
#
# So ~86% of the write volume was produced OUTSIDE every throttle, on a box
# whose root disk the whole sh2-io-max mechanism exists to protect. The
# workers that supervise.sh deliberately puts in the slice are bounded; the
# ones that slip through are not. Bounding is opt-in and the default is
# unbounded — that is the loophole, and no amount of tuning the existing caps
# closes it.
#
# WHY init.scope SPECIFICALLY, and not "the root cgroup". Under WSL2 the
# agent runs in a schroot, and /init.scope is where PID 1's siblings, every
# ad-hoc `bash` tool call, cron, and anything not explicitly enrolled lands.
# It is the containing scope for the whole session, so it is the right place
# for a BACKSTOP: a ceiling on the unbounded default path, not a throttle on
# any one worker.
#
# WHAT THIS DOES *NOT* CLAIM. io.max throttles IO, not page cache. Measured
# at the time of writing, init.scope held file=33.0 GB against anon=0.69 GB —
# 95% of its accounted memory was page cache, and dirty bytes were pinned low
# by vm.dirty_bytes/dirty_background_bytes (1.5 GB / 512 MB), so writeback is
# already bounded by the dirty limits rather than by io.max. A cap here bounds
# how fast the disk is driven; it does NOT bound cache growth. That is the
# memory.high / memory.reclaim half of the problem, and it is deliberately
# NOT faked here — see the LIMITS note in sh2-io-max.sh. The value below is
# therefore deliberately LOOSE: it is a backstop against one runaway writer
# saturating a 70-90 MB/s device, not a bandwidth budget for the fleet. The
# per-worker slices remain the real throttle and their 32 MiB/s is the number
# that should bind first.
#
# The maj:min of the root disk is NOT stable across reboots (it was 8:48 here
# and stat has been observed reporting 8:30 for the same device), so it is
# re-resolved from findmnt on every run — never hardcoded. Writing an
# io.max for a device that does not exist is rejected outright by the kernel,
# and the cap then silently never applies.
#
# Env-tunable so an operator can retune without editing a unit:
#   SH2_SCOPE_RBPS / SH2_SCOPE_WBPS / SH2_SCOPE_RIOPS / SH2_SCOPE_WIOPS
set -e

SCOPE="${SH2_CONTAIN_SCOPE:-init.scope}"

# Locate the cgroup directory. Under systemd an X.scope lives under its unit
# path; search rather than guess, exactly as sh2-io-max.sh does.
find_cg() {
    _n="$1"
    for _c in "/sys/fs/cgroup/$_n" \
             "/sys/fs/cgroup/system.slice/$_n" \
             "/user.slice/user-0.slice/$_n"; do
        [ -d "$_c" ] && { echo "$_c"; return 0; }
    done
    find /sys/fs/cgroup -maxdepth 2 -type d -name "$_n" 2>/dev/null | head -1
}

cg=$(find_cg "$SCOPE")
if [ -z "$cg" ]; then
    # A scope exists for the whole session (PID 1 lives in it), so this is
    # genuinely unexpected — but a missing backstop must never be fatal.
    echo "sh2-contain: scope $SCOPE not found — no backstop applied" >&2
    exit 0
fi

majmin=$(findmnt -no MAJ:MIN -T / 2>/dev/null)
if [ -z "$majmin" ] || [ "$majmin" = "0:0" ]; then
    echo "sh2-contain: could not resolve a device for / (got '$majmin')" >&2
    exit 0
fi

# LOOSE on purpose — see the block comment above. rbps=100 MB/s sits above
# the measured 70-90 MB/s device ceiling (a cap above the achievable rate is
# decoration, not a throttle) only in the sense that it does not bind on a
# single normal writer; wbps=32 MiB/s MATCHES the per-worker slices, so a
# writer that escaped them gets no more budget than one that did not, while
# N workers can still share the device. riops/riops are left effectively
# open because the harness's measured gate traffic is ~130 IOPS.
rbps=${SH2_SCOPE_RBPS:-104857600}
wbps=${SH2_SCOPE_WBPS:-33554432}
riops=${SH2_SCOPE_RIOPS:-400}
wiops=${SH2_SCOPE_WIOPS:-2000}

if printf '%s rbps=%s wbps=%s riops=%s wiops=%s\n' \
    "$majmin" "$rbps" "$wbps" "$riops" "$wiops" > "$cg/io.max" 2>/dev/null; then
    echo "sh2-contain: $cg -> $(cat "$cg/io.max")"
else
    # Not fatal: the harness must run unthrottled rather than not at all.
    echo "sh2-contain: FAILED to write $cg/io.max (continuing unthrottled)" >&2
    exit 0
fi
