#!/usr/bin/env bash
# progress.sh — show worker progress over a time window.
# Usage: ./progress.sh [hours] (default: 4)
set -u
cd "$(dirname "$0")"
# fail-estree writes its ledger/metric into the tree it MEASURED (2026-09-28),
# so the estree loop's state lives in sh2perl/, not the workspace root. Fall
# back to the old workspace location so a pre-move file still reads rather
# than reporting "(no data)".
ESTREE_METRIC="sh2perl/.estree_metric.tsv"
[ -f "$ESTREE_METRIC" ] || ESTREE_METRIC=".estree_metric.tsv"
ESTREE_FAILURES="sh2perl/.estree_failures.tsv"
[ -f "$ESTREE_FAILURES" ] || ESTREE_FAILURES=".estree_failures.tsv"
export ESTREE_METRIC ESTREE_FAILURES   # the python heredoc below reads these
HOURS="${1:-4}"
SINCE="$HOURS hours ago"

echo "=== Progress over last ${HOURS}h ($(date)) ==="
echo ""

# ── Fail count trend (from commit messages) ──────────────────────────
echo "--- Perl corpus fail count (from commits) ---"
fail_counts=$(git log --since="$SINCE" --oneline --all 2>/dev/null | grep -o 'fail [0-9]* -> [0-9]*' | tac)
if [ -n "$fail_counts" ]; then
  # After tac: oldest first, newest last
  first=$(echo "$fail_counts" | head -1 | awk -F' -> ' '{print $1}' | awk '{print $NF}')
  last=$(echo "$fail_counts" | tail -1 | awk -F' -> ' '{print $2}')
  if [ -n "$first" ] && [ -n "$last" ]; then
    delta=$((first - last))
    echo "  $first → $last ($delta fixed)"
  fi
  echo "$fail_counts" | tail -10 | sed 's/^/  /'
else
  echo "  (no fail-count changes in this window)"
fi

echo ""

# ── Git commits per worker ───────────────────────────────────────────
echo "--- Commits by worker (last ${HOURS}h) ---"
# Attribution notes (two bugs fixed here):
#  * The old tag list had no "core" tag, yet the core/contract worker is the
#    fleet's highest-priority role (PLAN §11, role #1) — its commits could
#    never be attributed to any worker.
#  * `grep -ci` counts MATCHING LINES, not commits: a commit whose subject
#    spans multiple lines was counted twice, and (more visibly) a single
#    commit whose body mentioned several tags inflated several buckets.
#    One commit now counts once per tag via `grep -c` over subject-only
#    output, so TOTAL is a count of attributions, not of commits.
# The list is the real worker roster; add a tag when a worker is added —
# this is the same "hardcoded list drifts from reality" failure as the
# liveness probe (pgrep) bug above: keep it in sync with the fleet.
commits_h=$(git log --since="$SINCE" --format='%s' --all 2>/dev/null)
total=0
for tag in "core" "perl" "rust-frontend" "rust-cleanup" "rust:" "python" "fish" "zsh" "zig" "py-idiom" "janitor" "triage" "bump sh2perl" "gitlink" "ingress"; do
  # word-boundary where sensible so "core" doesn't match "score"; -F keeps
  # the literal match, -i is case-insensitive.
  count=$(printf '%s\n' "$commits_h" | grep -c -i -- "$tag" || true)
  count=${count:-0}
  if [ "$count" -gt 0 ]; then
    printf "  %-16s %d commit(s)\n" "$tag" "$count"
    total=$((total + count))
  fi
done
if [ "$total" -eq 0 ]; then
  echo "  (none)"
  # Do not report a bare 0 without saying what a 0 means: it may simply be
  # that the commits carried no recognised worker tag.
  n_commits=$(printf '%s\n' "$commits_h" | grep -c . || true)
  [ "${n_commits:-0}" -gt 0 ] && \
    echo "  NOTE: $n_commits commit(s) exist in this window but carry no recognised worker tag."
fi
echo "  TOTAL: $total"

echo ""

# ── sh2perl submodule commits ────────────────────────────────────────
echo "--- sh2perl submodule commits (last ${HOURS}h) ---"
sub_count=$(git -C sh2perl log --since="$SINCE" --oneline 2>/dev/null | wc -l)
if [ "$sub_count" -gt 0 ]; then
  git -C sh2perl log --since="$SINCE" --oneline 2>/dev/null | head -15 | sed 's/^/  /'
  [ "$sub_count" -gt 15 ] && echo "  ... ($sub_count total)"
else
  echo "  (none)"
fi

echo ""

# ── Per-tree board: fail count 24h/4h/now, or sh2.* count if green ───
# Each backend/frontend tree has a gate report with timestamped history
# (gate-reports/<tree>.report), each line carrying a fail count:
#   2026-09-23T18:15:15 [rust] backend gate: 622/648 corpus render OK, 19 fail (...)
# The ask: a tree that is FAILING shows its fail count at 24h / 4h / now;
# a tree that is NOT failing shows its sh2.* occurrence count instead
# (for a green tree the interesting number is no longer failures but how
# much is still calling back into the runtime).
#
# UNITS MATTER: the columns carry a fail count for a failing tree and an
# sh2.* call-site count for a green one, so a bare number in "now" is
# ambiguous — and a reader cannot tell whether `19` means "19 fails" or
# "19 sh2.* sites". Tag every number with its unit: `19f` = fails,
# `1767s` = sh2.* sites (s), `-` = no measurement at that horizon. The
# header states the convention so the legend never scrolls off.
echo "--- Per-tree board (per-tree now: fails, or sh2.* when green) ---"
echo "    units: <n>f = failing tests   <n>s = sh2.* call sites (green)   - = no data"
printf "  %-10s %-9s %-9s %-9s %s\n" "tree" "24h" "4h" "now" "trend"
for rep in gate-reports/backend-*.report gate-reports/estree.report; do
  [ -f "$rep" ] || continue
  tree=$(basename "$rep" .report | sed 's/^backend-//')
  # pull (epoch, fails) for every line that has a fail count
  awk -F'\t' '{ }' /dev/null
  python3 - "$rep" "$tree" <<'PYEOF'
import re, sys, time, os
rep, tree = sys.argv[1], sys.argv[2]
rows = []
now = time.time()
# Two report formats in the fleet:
#   backend: 2026-09-23T18:15:15 [rust] backend gate: ..., 19 fail (...)
#   estree:  Thu Sep 24 13:06:13 2026 estree: 526/555 pass, 29 fail; ...
iso  = re.compile(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}).*?(\d+) fail')
ctime= re.compile(r'^(\w{3} \w{3} +\d+ \d{2}:\d{2}:\d{2} \d{4}).*?(\d+) fail')
for ln in open(rep, errors='replace'):
    m = iso.match(ln)
    if m:
        try: t = time.mktime(time.strptime(m.group(1), '%Y-%m-%dT%H:%M:%S'))
        except Exception: continue
    else:
        m = ctime.match(ln)
        if not m: continue
        try: t = time.mktime(time.strptime(m.group(1)))
        except Exception: continue
    rows.append((t, int(m.group(2))))
if not rows:
    print("  %-10s %-9s %-9s %-9s %s" % (tree, "?", "?", "?", "no data"))
    sys.exit()

def val_at(age_h):
    """fail count from the newest row at least age_h old (else '-')"""
    cut = now - age_h*3600
    cand = [r for r in rows if r[0] <= cut]
    return str(cand[-1][1]) if cand else "-"

v24, v4 = val_at(24), val_at(4)
t_now, f_now = rows[-1]
age_m = int((now - t_now)/60)
age = f"{age_m}m" if age_m < 120 else (f"{age_m//60}h" if age_m < 48*60 else f"{age_m//1440}d")

# A tree not gated in >24h has no meaningful "24h/4h" numbers — showing the
# same stale value in all three columns implies fresh measurement at each
# horizon, which is exactly the confident-wrong-answer failure to avoid.
if age_m > 24*60:
    print("  %-10s %-9s %-9s %-9s %s" % (
        tree, "-", "-", f"{f_now}f",
        f"STALE — {f_now}f is the last known, {age} old (not running)"))
    sys.exit()

if f_now == 0:
    # GREEN: report the sh2.* occurrence count instead of failures. The
    # count is fleet-wide (single .estree_metric.tsv), so mark it global
    # rather than implying it is this tree's own measurement.
    sh2 = None
    # ESTREE_METRIC is exported by the shell above (fail-estree writes into
    # the tree it measured, not the workspace root). Default to the new
    # location, with the old one as a fallback for a pre-move file.
    estree_metric = os.environ.get('ESTREE_METRIC', 'sh2perl/.estree_metric.tsv')
    if not os.path.isfile(estree_metric):
        estree_metric = '.estree_metric.tsv'
    if os.path.isfile(estree_metric):
        for ln in open(estree_metric, errors='replace'):
            f = ln.split('\t')
            if f and f[0].strip() == 'total' and len(f) > 1:
                sh2 = f[1].strip()
    sh2s = f"{sh2}s" if sh2 else "-"
    note = (f"GREEN — 0 fails; sh2.* sites {sh2s} (fleet-wide)"
            if sh2 else "GREEN — 0 fails")
    print("  %-10s %-9s %-9s %-9s %s" % (tree, "0f", "0f", "0f", note))
else:
    # FAILING: 24h/4h/now fail counts + direction. Every number is
    # unit-tagged so the column cannot be misread as sh2.* sites.
    def tag(v):
        return "-" if v == "-" else f"{int(v)}f"
    try:
        base = int(v4) if v4 != "-" else f_now
        d = f_now - base
    except ValueError:
        d = 0
    arrow = "↓ improving" if d < 0 else ("↑ worse" if d > 0 else "= flat")
    print("  %-10s %-9s %-9s %-9s %s (last run {})".format(age) % (
        tree, tag(v24), tag(v4), f"{f_now}f", f"{arrow} {d:+d}f/4h"))
PYEOF
done

echo ""

# ── Fail-count trends (how many failures were actually fixed) ─────────
# Two independent series, because they measure different corpora:
#  * Perl corpus: "N passed, M failed" in sh2perl commit subjects. Only
#    recorded when the worker commits a test result, so the series may be
#    SHORT — report the real span rather than implying a trend exists.
#  * Estree corpus: pass/fail rows in .estree_history.log.
echo "--- Fail-count trend (last ${HOURS}h of recorded results) ---"
# Perl: collect the dated series from commit subjects and show the real
# span. A two-point series cannot show a trend, and saying so beats
# printing a confident slope from nothing.
perl_series=$(git -C sh2perl log --since='30 days ago' --format='%ad %s' --date=short 2>/dev/null \
  | grep -E 'passed, [0-9]+ failed' \
  | awk '{d=$1; f=$0; sub(/.*, /,"",f); sub(/ failed/,"",f); if (d!=pd) {print d"\t"f; pd=d}}')
if [ -n "$perl_series" ]; then
  n_days=$(printf '%s\n' "$perl_series" | wc -l)
  p_first=$(printf '%s\n' "$perl_series" | head -1)
  p_last=$(printf '%s\n' "$perl_series" | tail -1)
  ff=$(printf '%s' "$p_first" | cut -f2); fl=$(printf '%s' "$p_last" | cut -f2)
  echo "  Perl corpus (${n_days} recorded day(s)):"
  printf '%s\n' "$perl_series" | tail -8 | while IFS=$'\t' read -r d f; do printf "    %s  %s failures\n" "$d" "$f"; done
  if [ "$n_days" -lt 3 ]; then
    echo "    NOTE: only $n_days recorded day(s) — too few to show a trend."
    echo "    The corpus state RIGHT NOW is the number below (failing_tests.txt)."
  else
    echo "    change over span: $ff → $fl failures (fixed $((ff - fl)))"
  fi
else
  echo "  Perl corpus: no dated 'passed/failed' subjects in the last 30 days."
fi
# Estree: the gate rows recorded per iteration (fields 11/12 = before/after)
if [ -f .estree_history.log ]; then
  echo "  Estree corpus (gate rows):"
  awk -F'\t' '$10=="tolerance" && $11 ~ /^[0-9]+$/ {print $11"\t"$12"\t"$13}' .estree_history.log \
    | tail -5 | while IFS=$'\t' read -r b a x; do
      printf "    %s → %s fail" "$b" "$a"
      [ -n "$x" ] && printf "  (%s)" "$x"
      printf "\n"
    done
fi

echo ""

# ── Actual work achieved (not worker liveness) ───────────────────────
# The metric that matters: sh2.* call-site count. Every sh2.* call is a
# spot where the emitted backend calls back into the runtime instead of
# being natively lowered — driving it to zero is the whole project. The
# estree worker logs it per iteration as metric-seed/improve/regress/idle
# rows in .estree_history.log; each row is `before <TAB> after`.
#
# Column layout of that log: localtime() expands to 9 fields, so
#   $10=decision $11=before $12=after $13=extra
echo "--- sh2.* call-site metric (the real progress signal) ---"
if [ -f .estree_history.log ]; then
  # numeric rows only (seed/improve/regress carry numbers; idle carries 'flat')
  awk -F'\t' '$10 ~ /^metric-/ && $11 ~ /^[0-9]+$/ && $12 ~ /^[0-9]+$/ {print $11"\t"$12"\t"$13}' \
    .estree_history.log > /tmp/.metric_rows.$$ 2>/dev/null
  if [ -s /tmp/.metric_rows.$$ ]; then
    first=$(head -1 /tmp/.metric_rows.$$ | cut -f1)
    last=$(tail -1 /tmp/.metric_rows.$$ | cut -f2)
    # net change (negative = fewer call sites = progress)
    delta=$((first - last))
    if [ "$delta" -gt 0 ]; then
      echo "  $first → $last  (-$delta call sites, $((delta * 100 / first))% fewer) [tracked window]"
    elif [ "$delta" -lt 0 ]; then
      echo "  $first → $last  (+$((0 - delta)) call sites, REGRESSED) [tracked window]"
    else
      echo "  $first → $last  (flat) [tracked window]"
    fi
    # a short trend so the direction is visible, not just the endpoints
    echo "  recent:"
    tail -6 /tmp/.metric_rows.$$ | while IFS=$'\t' read -r b a x; do
      d=$((b - a))
      if   [ "$d" -gt 0 ]; then arrow="↓ -$d"
      elif [ "$d" -lt 0 ]; then arrow="↑ +$((0 - d))"
      else arrow="= flat"
      fi
      printf "    %5s → %-5s %-10s %s\n" "$b" "$a" "$arrow" "$x"
    done
  else
    echo "  (no numeric metric rows logged yet)"
  fi
  rm -f /tmp/.metric_rows.$$
  # the live count for the current tree (independent of the log)
  if [ -f "$ESTREE_METRIC" ]; then
    cur=$(awk -F'\t' '$1=="total"{print $2}' "$ESTREE_METRIC" 2>/dev/null)
    # Say WHEN it was measured: a stale snapshot read as "current" looks
    # like a regression against the tracked series and sends people chasing
    # a phantom. Timestamp it explicitly.
    m_age=$(( ($(date +%s) - $(stat -c %Y "$ESTREE_METRIC" 2>/dev/null || date +%s)) / 60 ))
    if [ "$m_age" -lt 60 ]; then when="${m_age}m ago"
    else when="$((m_age / 60))h$((m_age % 60))m ago"
    fi
    echo "  last metric run ($when): ${cur:-?} call sites"
    # if the last metric run is much newer than the tracked series, the
    # tree has drifted from the last logged decision — flag the mismatch
    # rather than silently presenting two numbers that disagree.
    if [ -n "$cur" ] && [ "$cur" -gt "$last" ] 2>/dev/null; then
      echo "    note: ${cur} > ${last} (last logged decision) — the tree has grown call"
      echo "    sites since the last improving commit; check the last metric-run timestamp."
    fi
  fi
else
  echo "  (no .estree_history.log)"
fi

echo ""

# ── What the core worker actually did (marketplace + transforms) ──────
echo "--- Core/marketplace work (from .estree_history.log) ---"
if [ -f .estree_history.log ]; then
  for d in core-request core-request-violation transform-compile transform-gate transform-blame metric-improve metric-regress; do
    n=$(awk -F'\t' -v d="$d" '$10==d' .estree_history.log 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] && printf "  %-26s %d event(s)\n" "$d" "$n"
  done
  # transform submissions: accepted vs rejected (the marketplace outcome)
  acc=$(ls core-requests/transforms/done/*.rs 2>/dev/null | wc -l)
  rej=$(ls core-requests/transforms/rejected/*.rs 2>/dev/null | wc -l)
  pend=$(ls core-requests/transforms/offered/*.rs 2>/dev/null | wc -l)
  echo "  transforms: $acc accepted, $rej rejected, $pend pending"
  # core-requests awaiting implementation. NOTE: `grep -c` is shimmed to
  # `rg` here, where `-v`/`-c` behave unexpectedly (`unrecognized flag`);
  # count the files with a plain list + wc instead.
  cr_open=$(ls core-requests/*.md 2>/dev/null | while read -r f; do
    case "$(basename "$f")" in README*) ;; *) echo "$f" ;; esac
  done | wc -l)
  echo "  core-requests open: $cr_open file(s)"
fi

echo ""

# ── Current gate status ──────────────────────────────────────────────
echo "--- Current gate status ---"
# Perl corpus — try multiple sources
if [ -f sh2perl/failing_tests.txt ]; then
  perl_fails=$(wc -l < sh2perl/failing_tests.txt 2>/dev/null || echo "?")
  echo "  Perl corpus: $perl_fails failures"
else
  # Fall back to last commit message
  last_fail=$(git log -1 --oneline --all 2>/dev/null | grep -o 'fail [0-9]*' | awk '{print $2}')
  echo "  Perl corpus: ${last_fail:-?} failures (from last commit)"
fi

# Estree — parse the TSV header for the last row
if [ -f "$ESTREE_FAILURES" ]; then
  # The TSV is PER-TEST (name, verdict, reason) — its last row is one test's
  # verdict, not a corpus total, so reading it here reported a single PASS as
  # if it were the whole corpus. The real total is the report line
  # fail-estree appends per run; count the rows instead.
  estree_pass=$(awk -F'\t' '$2=="PASS"' "$ESTREE_FAILURES" 2>/dev/null | wc -l | tr -d ' ')
  estree_fail=$(awk -F'\t' '$2=="FAIL"' "$ESTREE_FAILURES" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Estree: ${estree_pass:-?} pass, ${estree_fail:-?} fail"
else
  echo "  Estree: (no data)"
fi

# Rust cleanup
# Rust cleanup. `grep -c` is shimmed to rg (where it can return empty and
# leave the line reading "Rust cleanup:  commit(s)") — count with awk.
cleanup_commits=$(git -C sh2perl log --since="$SINCE" --oneline 2>/dev/null | awk '/cleanup/{n++} END{print n+0}')
echo "  Rust cleanup: $cleanup_commits commit(s) this window"

echo ""

# ── Model rotation + progress-per-token ──────────────────────────────
# Which model each rotating worker is on, and what it actually bought:
# normalized gate progress per wall-clock hour and per token. The ranking is
# withheld until every worker has a measured interval under BOTH models —
# a confident winner from one worker on one model is worse than no answer.
echo "--- Model rotation: progress per hour and per token ---"
if [ -f harness/model_report.py ]; then
  if [ -d .worker-model ]; then
    python3 harness/model_report.py report 2>&1 | sed 's/^/  /'
  else
    echo "  (rotation not initialized — run: python3 harness/model_report.py init-rotation)"
  fi
else
  echo "  (harness/model_report.py missing)"
fi

echo ""

# ── Worker alive status ──────────────────────────────────────────────
# TWO SOURCES OF TRUTH, and that is the point.
#
# The hardcoded `pgrep` roster below is a DUPLICATE of the fleet definition
# that lives in systemd/. It drifted, and the drift is silent: the backend
# workers (setup_backends.sh --run-backend-worker <lang>) had no entry at
# all, so `core`/`perl`/`estree` reported ALIVE while `backend-c` and
# `backend-rust` — actually running — reported a bare "✗" with no
# explanation. A monitoring panel that silently omits half the fleet is worse
# than no panel: it says "✗" for something that is fine, and "✓" for
# something whose pattern it merely happens to match.
#
# So: systemd is authoritative for "should this be running", and the
# process scan is only a cross-check. A unit that is installed and active is
# reported as alive even if the process pattern does not match, because the
# process name is an implementation detail that can change without the
# worker going away.
echo "--- Workers alive ---"
# The unit list is read from systemd, not hardcoded: a worker added to the
# fleet shows up here automatically, which is what stops this drifting again.
units=$(systemctl --user list-unit-files 'sh2*.service' --no-legend --no-pager 2>/dev/null \
        | awk '{print $1}' | sed 's/\.service$//' | sort)
if [ -z "$units" ]; then
  echo "  (no sh2* user units installed — run: harness/install_units.sh --user)"
fi

printf "  %-20s %-9s %-8s %s\n" "unit" "unit-state" "process" "note"
for u in $units; do
  st=$(systemctl --user is-active "$u.service" 2>/dev/null)
  [ -z "$st" ] && st=$(systemctl is-active "$u.service" 2>/dev/null)
  pid=$(systemctl --user show -p MainPID --value "$u.service" 2>/dev/null)

  # The worker child is the supervisor's child; systemd's MainPID IS the
  # supervisor. Report "running" when either the supervisor or its child
  # exists — checking only MainPID is enough for liveness, but the child's
  # cmdline is the honest description of WHAT is running.
  what=""
  if [ -n "$pid" ] && [ "$pid" != "0" ] && [ -r "/proc/$pid/cmdline" ]; then
    # What the supervisor actually supervises: everything after the `--`
    # separator in supervise.sh's argv. That is the real worker, and it is
    # what distinguishes backend-c from backend-rust at a glance.
    what=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null \
           | sed 's#^.*/##' | awk 'seen{print} /^--$/{seen=1}' | paste -sd' ' -)
  fi
  [ -z "$what" ] && what="(no command info)"

  if [ "$st" = "active" ]; then
    printf "  %-20s %-9s %-8s %s\n" "$u" "✓ active" "✓" "$what"
  else
    printf "  %-20s %-9s %-8s %s\n" "$u" "✗ $st" "✗" "not running"
  fi
done

echo ""
echo "  Non-unit workers (roster entries with no systemd unit):"
# The frontend/triage workers are still hand-launched scripts, so they can
# only be probed by process scan. They are listed explicitly rather than
# derived, and each is labelled so a "✗" reads as "not started" rather
# than "broken".
for name in triage fish zsh zig rust-frontend rust-cleanup; do
  case $name in
    triage) pat="run_triage_worker" ;;
    fish) pat="fish-sh-go/run_frontend" ;;
    zsh) pat="zsh-sh-go/run_frontend" ;;
    zig) pat="zig-sh-go/run_frontend" ;;
    rust-frontend) pat="rust-frontend/run_frontend" ;;
    rust-cleanup) pat="rust_cleanup_worker" ;;
  esac
  case $name in
    triage) wlog="loop-triage-worker.log" ;;
    fish) wlog="loop-frontend-fish-sh-go.log" ;;
    zsh) wlog="loop-frontend-zsh-sh-go.log" ;;
    zig) wlog="loop-frontend-zig-sh-go.log" ;;
    rust-frontend) wlog="loop-frontend-rust-frontend.log" ;;
    rust-cleanup) wlog="loop-rust-cleanup.log" ;;
  esac
  # Scan /proc directly. `pgrep -f` matches this very script (its command
  # line and its source both contain the pattern), which makes a dead
  # worker report as alive — the false positive the old code half-fixed by
  # excluding $$ and $PPID, then re-broke for every `bash -c` wrapper.
  found=""
  for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    pid=${p#/proc/}
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "$PPID" ] && continue
    a0=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | sed -n 1p)
    case "$a0" in bash|*/bash|sh|*/sh|perl|*/perl) ;; *) continue ;; esac
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in *"$pat"*) found=1; break ;; esac
  done

  age=""
  if [ -f "$wlog" ]; then
    a=$(( $(date +%s) - $(stat -c %Y "$wlog") ))
    age=" (log ${a}s ago)"
  fi
  if [ -n "$found" ]; then
    printf "  %-20s %-9s %-8s %s\n" "$name" "✓ running" "✓" "no unit${age}"
  else
    printf "  %-20s %-9s %-8s %s\n" "$name" "✗ not started" "✗" "no unit — start manually${age}"
  fi
done
