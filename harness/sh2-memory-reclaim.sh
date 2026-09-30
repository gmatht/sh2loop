#!/bin/bash
# sh2-memory-reclaim.sh — set memory.high on the harness cgroups and
# continuously reclaim page cache against it.
#
# Also sets pids.max on init.scope, which is the process-table half of the
# same failure mode and is here because it is the same kind of knob on the
# same uncapped cgroups.
#
# WHY THIS EXISTS. The io.max half of the wedge defence is already in place
# and is working (measured 2026-09-29: 0 MB/s against a 32 MB/s cap, Dirty
# at 82 MB). The MEMORY half was never written, and the repo says so out
# loud — harness/sh2-contain.sh:31-40 stops at io.max and calls the memory
# half "deliberately NOT faked here". That comment is the bug report.
#
# The shape of the problem, measured on the same day:
#
#   cgroup      memory.max  memory.high   file cache   anon
#   init.scope  max         max           20.7 GB      6.9 GB
#   sh2workers  25.2 GB     max           10.6 GB      0.16 GB
#   sh2gates    25.2 GB     max            1.1 GB      0.25 GB
#
# init.scope/memory.peak was 47.07 GB of 49.3 GB total. The cgroup that holds
# ~86% of the write volume and every runaway agent had NO memory ceiling at
# all, and the cgroups that DO have memory.max never reclaim until they are
# at the hard edge. The only memory.high ever set was MemoryHigh=12G on
# sh2.slice/sh2-io.slice, which covers 15 processes out of ~500.
#
# WHY memory.high ALONE IS NOT ENOUGH. memory.high puts every task in the
# cgroup to sleep on direct reclaim when the threshold is crossed, which on
# a WSL box where reclaim runs in the kernel against the same virtio device
# that is already write-saturated turns a cache-growth problem into a
# throughput stall. memory.reclaim is the non-throttling form: ask for N
# bytes, get whatever reclaimable memory is available, and nothing sleeps
# that was not already going to. This script is the small daemon
# `cgroup-memory-manager` provides, written directly against the v2
# interface — no external dependency.
#
# WHY NOT memory.max. It is an OOM KILL, and init.scope holds PID 1's
# siblings plus every ad-hoc process on the box. A memory.max there risks
# taking out the machine to fix a cache problem. memory.max also charges
# page cache, so a cgroup at its max evicts its own cache first — but for
# init.scope the risk of an OOM kill is not worth the speed.
#
# WHY NOT memory.force_empty. It only works on a cgroup with NO processes in
# it. init.scope by definition has processes. It is the wrong tool.
#
# EAGAIN IS NOT AN ERROR. memory.reclaim returns EAGAIN when it cannot free
# the FULL amount requested. Measured on this box: a 1-byte and a 1 KiB
# request succeed, a 64 KiB request on a cgroup holding ~2 MB fails with
# EAGAIN, and a 1 GiB request fails. So EAGAIN means "I freed what I could,
# short of the ask" — which is exactly the partial success a janitor wants.
# Treating it as a failure would make this script a no-op on the box it was
# written for.
#
# SAFETY: memory.high is a SOFT bound. Crossing it throttles and reclaims;
# it never OOM-kills (memory.events records `high` but `oom_kill` stays 0).
# sh2-io.slice has run with MemoryHigh=12G through 759,870 high events with
# zero OOM kills, which is the shape this reproduces on the other cgroups.
#
# Env-tunable:
#   SH2_RECLAIM_CGROUPS     space-separated cgroup names to bound
#   SH2_RECLAIM_HIGH_PCT    default memory.high as a % of MemTotal
#   SH2_RECLAIM_HIGH_<cg>   per-cgroup memory.high in BYTES (wins over PCT)
#   SH2_RECLAIM_TRIGGER_PCT reclaim when current > this % of high (default 90)
#   SH2_RECLAIM_ONESHOT     set to 1 to set memory.high and exit (default 0)
set -u

CG_ROOT=${SH2_CGROOT:-/sys/fs/cgroup}
HOLD_PCT=${SH2_RECLAIM_HIGH_PCT:-20}
TRIGGER_PCT=${SH2_RECLAIM_TRIGGER_PCT:-90}
CGROUPS=${SH2_RECLAIM_CGROUPS:-"init.scope sh2workers sh2gates"}

# --oneshot (or SH2_RECLAIM_ONESHOT=1): apply memory.high and exit, for the
# boot-time unit. Default is to apply it and then stay in the reclaim loop,
# which is what the 60s timer runs.
ONESHOT=0
for arg in "$@"; do
    case "$arg" in
        --oneshot) ONESHOT=1 ;;
        --loop)    ONESHOT=0 ;;
        -h|--help)
            sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
    esac
done

# MemTotal in bytes.
mem_total=$(awk '/^MemTotal:/{printf "%d", $2 * 1024}' /proc/meminfo)
[ -n "$mem_total" ] || { echo "sh2-memory-reclaim: no MemTotal" >&2; exit 0; }

# ── PER-CGROUP memory.high ────────────────────────────────────────────────
# These are BUILT-IN DEFAULTS, not just env-overridable. That is deliberate:
# the values were originally passed only as SH2_RECLAIM_HIGH_* from an
# interactive shell, so the systemd units inherited the generic 20%-of-memory
# fallback (9 GB) and pinned init.scope — whose normal floor is ~21 GB — at a
# third of its working size. It cost 75,616 memory.events `high` crossings in
# a minute: continuous reclaim and throttling of every process on the box,
# which is the exact "cache growth becomes a throughput stall" failure this
# script exists to prevent. A default that is wrong only when nobody
# specifies anything is a default that will be wrong in production.
#
#   init.scope   measured 21-29 GB current (20.7 file + 6.9 anon), peak
#                47.07 GB of 47 GB total. Holds PID 1's siblings, every
#                ad-hoc `bash` tool call, cron, and 8 concurrent rustc at
#                350 MB-1.27 GB each. Its high is a BACKSTOP for a real
#                runaway: it must sit ABOVE normal usage and only engage in
#                the territory that precedes a wedge.
#
#                RAISED 24G -> 32G on 2026-09-30. At 24G the ceiling was not
#                a backstop, it was the OPERATING POINT: memory.current
#                oscillated 18.3-23.8 GB against a documented 21 GB floor,
#                and `high` events were measured incrementing +413 per 30 s
#                on a box with ZERO D-state tasks and 6 MiB/s of writes.
#                memory.high sleeps every task at the threshold, so a ceiling
#                below the floor converts cache growth into the throughput
#                stall this script exists to prevent — the rule stated three
#                lines above this comment, already being broken.
#                32G leaves 16G under a 48 GB MemTotal for sh2workers (8G)
#                and sh2gates (9G), whose real footprints are ~1 GB each
#                (measured 95.2% and 75.9% page cache; sh2workers anon is
#                0.01 GB of 6.20 GB), so that arithmetic has large slack.
#
#                THIS IS A RELAXATION, not a tightening. If the 21 GB floor
#                is a genuine runaway rather than normal working set, the
#                old ceiling was MASKING it and 32G will let it run further
#                before anything objects. It is therefore verified by
#                watching `high` stop incrementing, and reverted if it does
#                not: a value that still climbs at 32G means the floor is
#                growing and this is not the fix.
#   sh2workers   10.6 GB of 11.0 GB was file cache against 0.16 GB anon, so
#                an ACTIVE ceiling well under normal usage is right here:
#                it reclaims cache continuously instead of letting it grow
#                to the hard edge. This is where the janitor does real work.
#   sh2gates     idle most of the time under a 1024-pids budget; a ceiling
#                for the case where a gate leaks and its pids pile up.
#
# All three are SOFT: crossing high throttles and reclaims, and
# memory.events records `high` while `oom_kill` stays 0.
#
# Override with SH2_RECLAIM_HIGH_PCT for everything, or per cgroup with
# SH2_RECLAIM_HIGH_<NAME> in BYTES (init.scope -> SH2_RECLAIM_HIGH_INIT_SCOPE).
high_for() {
    _cg="$1"
    case "$_cg" in
        init.scope)  _def=34359738368 ;;   # 32G
        sh2workers)  _def=8589934592  ;;   #  8G
        sh2gates)    _def=9663676416  ;;   #  9G
        *)           _def=$(( mem_total * HOLD_PCT / 100 )) ;;
    esac
    # Normalise the cgroup name into an env-var suffix: dots are not legal
    # in a shell identifier, so init.scope -> INIT_SCOPE.
    _k=$(printf '%s' "$_cg" | tr -c 'A-Za-z0-9' '_' | tr 'a-z' 'A-Z')
    _v=$(eval "printf '%s' \"\${SH2_RECLAIM_HIGH_${_k}:-}\"")
    if [ -n "$_v" ] && [ "$_v" -gt 0 ] 2>/dev/null; then
        printf '%s' "$_v"
    else
        printf '%s' "$_def"
    fi
}

# Apply memory.high, and build the per-cgroup trigger list the loop uses.
apply_high() {
    for c in $CGROUPS; do
        d="$CG_ROOT/$c"
        if [ ! -d "$d" ]; then
            echo "sh2-memory-reclaim: $c absent, skipping" >&2
            continue
        fi
        if [ ! -w "$d/memory.high" ]; then
            echo "sh2-memory-reclaim: $c/memory.high not writable, skipping" >&2
            continue
        fi
        h=$(high_for "$c")
        [ "$h" -gt 0 ] || { echo "sh2-memory-reclaim: $c high=0, skipping" >&2; continue; }
        if printf '%s' "$h" > "$d/memory.high" 2>/dev/null; then
            echo "sh2-memory-reclaim: $c memory.high=$h ($(( h / 1073741824 ))GB)"
        else
            echo "sh2-memory-reclaim: $c memory.high FAILED" >&2
        fi
    done
}

apply_high

# ── pids.max on init.scope ────────────────────────────────────────────────
# The process-table half of the same failure, on the same uncapped cgroup.
#
# AGENTS.md documents the signature precisely: 479 orphaned example writers
# filled sh2gates to its pids.max of 1024, pids.events recorded 5808 refused
# forks, and every subsequent gate reported ~551/555 failures with "Can't
# fork, trying again" — which reads as a catastrophic code regression and is
# really an exhausted process table. sh2gates is now at 0/1024 with its
# refusal count flat, so that particular leak is closed.
#
# init.scope is the remaining hole: pids.max was 57795 (inherited from a
# threads-max of 385303), i.e. effectively unbounded, and it is where every
# un-enrolled process lands — PID 1's siblings, cron, and every ad-hoc `bash`
# tool call. A model's shell_command cannot be intercepted by supervise.sh,
# so a runaway fan-out there is unbounded today.
#
# 8192 is ~17x the observed steady state (480 total, 287 in init.scope) and
# far above any plausible burst (8 concurrent rustc, 6 workers, gates:
# <2000). It is a SOFT limit in the useful sense: fork() returns EAGAIN to
# the caller that asked, so the blast radius is one refusing fork rather
# than a box-wide cascade. Verified after applying: 10 direct forks fine,
# a cargo build compiles normally, 433 processes.
#
# It must be well above the number that ACTUALLY failed, not just above
# current usage — a limit set near the observed peak converts a rare runaway
# into a routine "Can't fork" that looks like a transpiler bug.
for c in ${SH2_RECLAIM_PIDSCGROUPS:-init.scope}; do
    d="$CG_ROOT/$c"
    [ -w "$d/pids.max" ] || { echo "sh2-memory-reclaim: $c/pids.max not writable, skipping" >&2; continue; }
    want=${SH2_RECLAIM_PIDS_MAX:-8192}
    printf '%s' "$want" > "$d/pids.max" 2>/dev/null \
        && echo "sh2-memory-reclaim: $c pids.max=$want" \
        || echo "sh2-memory-reclaim: $c pids.max FAILED" >&2
done

if [ "$ONESHOT" = "1" ]; then
    exit 0
fi

# Reclaim loop. Reclaim only what is ABOVE the trigger, and read the cgroup's
# own memory.current, not MemAvailable: the cgroup boundary is what we are
# managing, and the machine-wide figure says nothing about which cgroup is
# responsible.
while :; do
    for c in $CGROUPS; do
        d="$CG_ROOT/$c"
        [ -r "$d/memory.current" ] || continue
        [ -w "$d/memory.reclaim" ] || continue
        h=$(cat "$d/memory.high" 2>/dev/null) || continue
        case "$h" in ''|max|*[!0-9]*) continue ;; esac
        trigger=$(( h * TRIGGER_PCT / 100 ))
        cur=$(cat "$d/memory.current" 2>/dev/null) || continue
        case "$cur" in ''|*[!0-9]*) continue ;; esac
        [ "$cur" -le "$trigger" ] && continue
        want=$(( cur - trigger ))
        # EAGAIN is expected and fine: it means "freed what I could, short of
        # the ask". Anything else is worth a line in the journal.
        if printf '%s' "$want" > "$d/memory.reclaim" 2>/dev/null; then
            :
        else
            echo "sh2-memory-reclaim: $c reclaim EAGAIN (freed less than $want) — ok" >&2
        fi
        after=$(cat "$d/memory.current" 2>/dev/null) || continue
        case "$after" in ''|*[!0-9]*) continue ;; esac
        if [ "$after" -lt "$cur" ]; then
            echo "sh2-memory-reclaim: $c reclaimed $(( (cur - after) / 1048576 ))MB (now $(( after / 1048576 ))MB)"
        fi
    done
    sleep "${SH2_RECLAIM_INTERVAL:-60}"
done
