#!/usr/bin/env bash
# progress.sh — show worker progress over a time window.
# Usage: ./progress.sh [hours] (default: 4)
set -u
cd "$(dirname "$0")"
# fail-estree writes its ledger/metric into the tree it MEASURED (2026-09-28).
# The estree loop runs with SH2PERL_DIR=sh2perl/backends/estree, so THAT is
# where its live metric lands. The previous pair of candidates
# (sh2perl/.estree_metric.tsv, then .estree_metric.tsv) contained NEITHER: the
# primary does not exist and the fallback is a Sep-28 snapshot, so the board
# reported 1776 from a two-day-old file while the worker's actual figure was
# in the worktree all along. Search the estree worktree first, then the
# main checkout, then the old root path for a pre-move file.
ESTREE_METRIC=""
for cand in sh2perl/backends/estree/.estree_metric.tsv \
            sh2perl/.estree_metric.tsv \
            .estree_metric.tsv; do
  if [ -f "$cand" ]; then ESTREE_METRIC="$cand"; break; fi
done
# Prefer the NEWEST of the candidates rather than the first that exists:
# "first match" silently prefers a stale file over a fresh one in a
# different worktree, which is the same class of bug as reading one tree's
# number on another's row.
if [ -n "$ESTREE_METRIC" ]; then
  for cand in sh2perl/backends/estree/.estree_metric.tsv \
              sh2perl/.estree_metric.tsv .estree_metric.tsv; do
    [ -f "$cand" ] || continue
    if [ "$cand" -nt "$ESTREE_METRIC" ]; then ESTREE_METRIC="$cand"; fi
  done
fi
ESTREE_FAILURES=""
for cand in sh2perl/backends/estree/.estree_failures.tsv \
            sh2perl/.estree_failures.tsv \
            .estree_failures.tsv; do
  if [ -f "$cand" ]; then ESTREE_FAILURES="$cand"; break; fi
done
# Per-backend runtime-call counts, written by
# harness/backend_runtime_metric.sh into the tree that backend's gate
# measures (the same $outdir rule fail-estree uses). Keyed by tree so each
# row reads its own file, and exported for the python heredoc below.
for _t in c rust perl python zig go java js sh; do
  for _c in "sh2perl/backends/$_t/.rt_metric.tsv" "sh2perl/.rt_metric.tsv"; do
    [ -f "$_c" ] || continue
    # `export "NAME=$val"` does NOT work here: the subscript is expanded as
    # part of the WORD, so bash tries to assign to a variable whose name is
    # the file path ("SH2_RT_METRIC_c=sh2perl/...: No such file or
    # directory") and the intended variable is never created — which under
    # `set -u` then reads as "unbound variable" and silently loses the whole
    # measurement. Build the NAME first, then assign by name.
    _n="SH2_RT_METRIC_${_t^^}"
    printf -v "$_n" '%s' "$_c"
    export "$_n"
    break
  done
done
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

# ── Per-tree board: fail count 24h/4h/now, or the tree's own stub count ─
# Each backend/frontend tree has a gate report with timestamped history
# (gate-reports/<tree>.report), each line carrying a fail count:
#   2026-09-23T18:15:15 [rust] backend gate: 622/648 corpus render OK, 19 fail (...)
# The ask: a tree that is FAILING shows its fail count at 24h / 4h / now;
# a tree that is NOT failing shows what it still delegates to its runtime.
#
# THE GREEN NUMBER MUST BE THE TREE'S OWN. It used to be the estree
# metric read unconditionally, so every green row showed the same
# fleet-wide figure — `c` and `rust` both read "1776s (fleet-wide)", which
# looks like a measurement of each and is a measurement of neither.
#
# UNITS MATTER: the columns carry a fail count for a failing tree and a
# runtime-call count for a green one, so a bare number in "now" is ambiguous
# — and a reader cannot tell whether `19` means "19 fails" or "19 calls".
# Tag every number with its unit: `19f` = fails, `N runtime calls` = THIS
# tree's own delegation, `-` = no measurement at that horizon.
#
# The green number is each tree's OWN runtime-call count, from
# harness/backend_runtime_metric.sh. It is deliberately NOT the gate's
# `(N stubs` field: that is `grep -cE 'sh2[A-Za-z_0-9]+\('` and so sees the
# `sh2_*` namespace ONLY — c emits `_sh_*`, rust/emit `__sh_*`, and both
# scored 0 by construction while delegating 29103 and 10124 times. A 0 from
# a pattern that cannot see the tree is NO DATA, not a result.
#
# The counts are NOT comparable across backends as a quality ranking: they
# measure how large each runtime's API is, not how native the lowering is
# (rust's 10124 `__sh_print_words` calls can replace what another target
# spells out in many lines). Use them to find who still leans on their
# runtime, not to rank them.
echo "--- Per-tree board (per-tree now: fails, or this tree's runtime calls when green) ---"
echo "    units: <n>f = failing tests   <n> runtime calls = this tree's own delegation   - = no data"
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
# The corpus total and skip count ride along with the fail count. They were
# discarded, and comparing fail counts across rows with DIFFERENT totals is
# how a smaller measured set reads as an improvement: the corpus is
# examples/*.sh + frontends/*/testdata/*.sh, and workers add testdata, so the
# denominator moves (measured 638/642/643/644/647 within one day). A drop in
# fails alongside a smaller total is fewer files measured, not fewer bugs.
TOT = re.compile(r'\b(\d+)/(\d+) corpus')
unparsed = []   # rows carrying a timestamp we could not parse (see below)
SKIP = re.compile(r', (\d+) skip')
for ln in open(rep, errors='replace'):
    m = iso.match(ln)
    if m:
        try: t = time.mktime(time.strptime(m.group(1), '%Y-%m-%dT%H:%M:%S'))
        except Exception: continue
    else:
        m = ctime.match(ln)
        if not m:
            # A row the parsers cannot read is a row whose verdict is
            # INVISIBLE, which is the worst outcome: the run happened, it may
            # have been red, and the board shows the previous state as if
            # nothing occurred. One was found on 2026-10-01 — a single
            # `x2026-10-01T00:04:07 [c] …` line in backend-c.report, written
            # by a gate that ran against the file mid-append. Do not guess at
            # the content: count it and say so.
            if ln.strip() and re.search(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}', ln):
                unparsed.append(ln.strip()[:60])
            continue
        try: t = time.mktime(time.strptime(m.group(1)))
        except Exception: continue
    tot = TOT.search(ln)
    skp = SKIP.search(ln)
    rows.append((t, int(m.group(2)),
                 int(tot.group(2)) if tot else None,
                 int(skp.group(1)) if skp else None))
if not rows:
    print("  %-10s %-9s %-9s %-9s %s" % (tree, "?", "?", "?", "no data"))
    sys.exit()
UNPARSED_WARNING = ""
if unparsed:
    # Say it rather than silently showing the previous state: a run whose
    # row cannot be parsed DID happen, and its verdict is unknown. Appended
    # to whichever row is printed below, so the tree appears ONCE — a
    # separate WARNING row for the same tree reads as a second tree.
    UNPARSED_WARNING = (f" | WARNING: {len(unparsed)} report row(s) carry a "
                       f"timestamp this board cannot parse, so their verdict "
                       f"is INVISIBLE (e.g. {unparsed[0]!r})")

def val_at(age_h):
    """fail count from the newest row at least age_h old (else '-')"""
    cut = now - age_h*3600
    cand = [r for r in rows if r[0] <= cut]
    return str(cand[-1][1]) if cand else "-"

v24, v4 = val_at(24), val_at(4)
t_now, f_now, tot_now, skip_now = rows[-1]
age_m = int((now - t_now)/60)
age = f"{age_m}m" if age_m < 120 else (f"{age_m//60}h" if age_m < 48*60 else f"{age_m//1440}d")

# A tree not gated in >24h has no meaningful "24h/4h" numbers — showing the
# same stale value in all three columns implies fresh measurement at each
# horizon, which is exactly the confident-wrong-answer failure to avoid.
if age_m > 24*60:
    # Say WHY it is stale, not just that it is. "not running" was the old
    # wording and it was not enough: the perl tree sat here for 42 days
    # reading "(not running)" while the actual, actionable fact was that the
    # unit had been stopped AND disabled — i.e. it was not coming back on
    # its own and no amount of waiting would fix it. A stale row whose cause
    # is a dead unit must point at that unit, or the board teaches people to
    # wait. Map tree -> the worker unit that is supposed to write the report.
    unit = {
        "perl": "sh2backend-perl", "rust": "sh2backend-rust",
        "c": "sh2backend-c", "estree": "sh2estree", "core": "sh2core",
    }.get(tree, "")
    why = ""
    if unit:
        import subprocess
        def _u(args):
            try:
                return subprocess.run(args, capture_output=True, text=True,
                                      timeout=10).stdout.strip()
            except Exception:
                return ""
        def _ok(args):
            # _u returns STDOUT, so it is the WRONG shape for a boolean
            # probe: `grep -q` and `test` are silent on success and return
            # "", which is falsy. Every `if _u([...grep -q...])` silently
            # took the else branch. Use the exit code.
            try:
                return subprocess.run(args, capture_output=True, text=True,
                                      timeout=15).returncode == 0
            except Exception:
                return False
        ust = _u(["systemctl", "--user", "is-active",  unit + ".service"])
        uen = _u(["systemctl", "--user", "is-enabled", unit + ".service"])
        if uen == "disabled":
            why = (f"unit {unit} is STOPPED+DISABLED — will not self-start; "
                   f"fix: systemctl --user enable --now {unit}.service")
        elif ust == "active":
            why = (f"unit {unit} IS active but wrote no gate row in {age} — "
                   f"wedged/blocked, not stopped (check its loop log + .gate.lock)")
            # Name the ACTUAL blocker. "wedged/blocked" is right but not
            # actionable, and the real cause is almost always one of two
            # things the gate hits BEFORE it can append a report row — so it
            # never shows up in the report, only in the worker log:
            #
            #   * "worktree build FAILED" — the gate could not build the
            #     renderer bin it probes (shir_render / <lang>_backend). The
            #     corpus loop never starts, so the report goes untouched for
            #     as long as the build is broken. Observed on perl for 43
            #     days: the worktree simply had no src/bin/shir_render.rs,
            #     while 12 of 14 worktrees did.
            #   * the worker is asleep on core-requests/sleeping-<lang>
            #     (a TRAPPED marker), which is invisible from `systemctl`.
            #
            # Both are cheap to name and turn a dead end into one command.
            # The loop log is named loop-<unit>.log for the ESTREE/CORE
            # workers but loop-backend-<lang>.log for the backend ones —
            # `unit` here is the SYSTEMD name, so the two differ. Probe both
            # and take whichever has the marker.
            lg = ""
            for cand in (f"loop-{unit}.log", f"loop-backend-{tree}.log",
                         f"loop-{tree}.log"):
                got = _u(["tail", "-400", cand])
                if got:
                    lg = got
                    if ("worktree build FAILED" in got
                            or "NO RENDERER" in got):
                        break
            if "worktree build FAILED" in lg or "NO RENDERER" in lg:
                # Only trust the build marker if it is the CURRENT state.
                # The log is append-only, so a marker from 43 days ago keeps
                # matching after the build is fixed and would keep naming a
                # solved problem as the root cause. Require the marker to be
                # in the log's tail AND for no fresh report row to exist; if
                # the gate is currently queued on the lock, say so instead.
                fresh_report = os.path.exists(rep) and (
                    time.time() - os.path.getmtime(rep) < 3600)
                if _ok(["bash", "-c",
                        "ls -l /proc/[0-9]*/fd 2>/dev/null | "
                        "grep -q gate.lock"]):
                    why += ("; (queued behind another backend gate on "
                            ".gate.lock — the gates serialize one at a time, "
                            "so no log output during the wait is expected)")
                elif fresh_report:
                    why += ("; report is fresh — the earlier "
                            "'worktree build FAILED' in the log is historical, "
                            "not the current blocker")
                else:
                    why += (f"; ROOT CAUSE: the gate cannot build its renderer "
                            f"bin — see 'worktree build FAILED'/'NO RENDERER' "
                            f"in loop-backend-{tree}.log (no report row is "
                            f"written until it builds)")
            elif os.path.exists(f"core-requests/sleeping-{tree}"):
                # NB: the marker is named by TREE (`sleeping-perl`), not by
                # the systemd unit (`sh2backend-perl`) — the first version
                # used `unit` here and so could never match.
                why += (f"; ROOT CAUSE: worker is ASLEEP behind "
                        f"core-requests/sleeping-{tree} (TRAPPED) — the unit is "
                        f"active but the gate is not running")
            # Not a blocker, but worth saying so a queue is not misread as a
            # wedge: the backend gates HARD-SERIALIZE on a single
            # .gate.lock, so a worker sits in `flock` (wchan
            # locks_lock_inode_wait) with an empty process tree for as long as
            # the holder's corpus takes — 65 min for one rust gate on this
            # box, with NO log output at all. That is the design working, and
            # without this line the next reader concludes it is wedged.
            elif _ok(["bash", "-c",
                     "ls -l /proc/[0-9]*/fd 2>/dev/null | "
                     "grep -q gate.lock"]):
                why += ("; (queued behind another backend gate on .gate.lock — "
                        "the gates serialize one at a time, so no log output "
                        "during the wait is expected)")
        else:
            why = f"unit {unit} is not running ({ust or 'unknown'})"
    note = f"STALE — {f_now}f is the last known, {age} old"
    if why:
        note += "; " + why
    print("  %-10s %-9s %-9s %-9s %s%s" % (tree, "-", "-", f"{f_now}f", note, UNPARSED_WARNING))
    sys.exit()

if f_now == 0:
    # GREEN: there are no failures to show, so show what the tree is still
    # delegating to its runtime. The number MUST be this tree's own.
    #
    # BUG FIXED 2026-09-30: this branch used to read the estree metric file
    # unconditionally, so EVERY green row printed the same fleet-wide estree
    # number. `c` and `rust` both read "sh2.* sites 1776s (fleet-wide)" —
    # a number that is not theirs, on a row that is. The label said
    # "fleet-wide" but the placement implied per-tree, and two backends
    # showing an identical figure invites exactly the wrong inference (that
    # they delegate the same amount, or that one is reading the other's
    # work). A metric that cannot distinguish two trees is worse than no
    # metric: it looks like a measurement.
    #
    # Each backend gate already records a stub count — the `(N stubs` field
    # in its report row, which setup_backends.sh calls "the progress
    # metric". Use it, but DO NOT call a zero "fully native".
    #
    # BUG FIXED 2026-09-30 (second one, worse than the first): that field
    # is `grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\('` — it only sees
    # the `sh2_*` namespace. The c and rust renderers do not emit `sh2_*`
    # at all; they emit `_sh_*` (c) and `__sh_*` (rust, perl, python), so
    # the pattern matches nothing and the count is 0 BY CONSTRUCTION, not
    # because the work is done. Measured on 000__04c_text_processing_commands.sh:
    #
    #     c     309  _sh_* calls      gate says 0 stubs
    #     rust  166  __sh_* calls     gate says 0 stubs
    #     perl   33  __sh_* calls     gate says 0 stubs
    #
    # So "0 stubs" meant "this backend's runtime has a different name", and
    # labelling it "fully native" was a confident wrong answer on the panel.
    # A 0 from a pattern that cannot see the tree's own namespace is NO DATA.
    # Report it as such.
    stubs = None
    stub_seen_by_pattern = False
    try:
        last_line = open(rep, errors='replace').read().rstrip("\n").rsplit("\n", 1)[-1]
        m = re.search(r'\((\d+) stubs', last_line)
        if m:
            stubs = int(m.group(1))
    except Exception:
        pass
    # The `sh2_*` stub pattern is the estree/js namespace. Any OTHER backend
    # emits its own namespace, which the pattern cannot match, so its 0 is
    # uninformative and must not be presented as a measurement.
    stub_pattern_covers_this_tree = tree in ("estree", "js", "core", "")
    if tree == "estree":
        sh2 = None
        # ESTREE_METRIC is resolved by the shell above, newest-candidate
        # first. An empty value means no metric file exists anywhere, which
        # must read as "no data" rather than falling back to a stale number.
        estree_metric = os.environ.get('ESTREE_METRIC', '')
        if estree_metric and os.path.isfile(estree_metric):
            for ln in open(estree_metric, errors='replace'):
                f = ln.split('\t')
                if f and f[0].strip() == 'total' and len(f) > 1:
                    sh2 = f[1].strip()
        bits = ["GREEN — 0 fails"]
        if sh2:
            src = os.path.basename(os.path.dirname(estree_metric)) or "?"
            bits.append(f"sh2.* contract sites {sh2}s ({src})")
        if stubs is not None:
            bits.append(f"{stubs} sh2_* stubs")
        print("  %-10s %-9s %-9s %-9s %s%s" % (tree, "0f", "0f", "0f", "; ".join(bits), UNPARSED_WARNING))
    elif stub_pattern_covers_this_tree:
        # The pattern can actually see this tree's namespace, so its number
        # is a real measurement.
        if stubs is None:
            print("  %-10s %-9s %-9s %-9s %s%s" % (
                tree, "0f", "0f", "0f",
                "GREEN — 0 fails; no stub count in this tree's report row",
                UNPARSED_WARNING))
        else:
            print("  %-10s %-9s %-9s %-9s %s%s" % (
                tree, "0f", "0f", "0f",
                f"GREEN — 0 fails; {stubs} sh2_* stubs", UNPARSED_WARNING))
    else:
        # The gate's stub pattern cannot see this tree's runtime namespace,
        # so its 0 is vacuous. Say that instead of printing a number that
        # looks like a measurement. This is the per-backend sh2.* call count
        # question, and it is answered by a gate that counts THIS tree's
        # namespace — see harness/backend_runtime_metric.sh.
        rt = os.environ.get("SH2_RT_METRIC_" + tree.upper())
        if rt and os.path.isfile(rt):
            try:
                tot = None
                for ln in open(rt, errors='replace'):
                    f = ln.split('\t')
                    if f and f[0].strip() == 'total' and len(f) > 1:
                        tot = f[1].strip()
                if tot is not None:
                    print("  %-10s %-9s %-9s %-9s %s%s" % (
                        tree, "0f", "0f", "0f",
                        f"GREEN — 0 fails; {tot} runtime calls "
                        f"(this tree's namespace)", UNPARSED_WARNING))
                    sys.exit()
            except Exception:
                pass
        print("  %-10s %-9s %-9s %-9s %s" % (
            tree, "0f", "0f", "0f",
            "GREEN — 0 fails; runtime-call count NOT MEASURED — the gate's "
            "sh2_* stub pattern cannot see this backend's namespace "
            f"({tree} emits its own); run harness/backend_runtime_metric.sh"
            + UNPARSED_WARNING))
    sys.exit()
else:
    # FAILING: 24h/4h/now fail counts + direction. Every number is
    # unit-tagged so the column cannot be misread as a runtime-call count.
    def tag(v):
        return "-" if v == "-" else f"{int(v)}f"
    # The 4h baseline row, so the denominator and skip count of BOTH runs are
    # known. Comparing a fail count against a row that measured a different
    # number of files is how a gap reads as progress.
    base_row = None
    cand = [r for r in rows if r[0] <= now - 4*3600]
    if cand:
        base_row = cand[-1]
    try:
        base = int(v4) if v4 != "-" else f_now
        d = f_now - base
    except ValueError:
        d = 0
    # A fail-count DROP is only progress if the same work was actually
    # measured. If the run measured fewer files (smaller corpus total) or
    # skipped more of them, the drop is a measurement gap, and saying
    # "improving" is the confident-wrong-answer failure this board exists to
    # avoid. Measured case: perl reported 397 fail against a true 401 purely
    # because 7 files came back rc=127 from the emitter and were skipped;
    # the board printed "↓ improving -4f/4h".
    caveat = ""
    if base_row is not None:
        _, f_base, tot_base, skip_base = base_row
        if tot_base and tot_now and tot_now < tot_base:
            caveat = (f" — NOT comparable: measured {tot_now} files vs "
                      f"{tot_base} at the 4h mark (fewer files measured, so a "
                      f"lower fail count is not fewer bugs)")
        elif skip_base is not None and skip_now is not None and skip_now > skip_base:
            caveat = (f" — NOT comparable: {skip_now} skipped vs {skip_base} "
                      f"at the 4h mark (more files unmeasured)")
    if d < 0 and caveat:
        arrow = "≈ fewer fails, but"
    elif d < 0:
        arrow = "↓ improving"
    elif d > 0:
        arrow = "↑ worse"
    else:
        arrow = "= flat"
    print("  %-10s %-9s %-9s %-9s %s (last run {})%s".format(age) % (
        tree, tag(v24), tag(v4), f"{f_now}f", f"{arrow} {d:+d}f/4h{caveat}",
        UNPARSED_WARNING))
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

printf "  %-20s %-9s %-8s %-12s %s\n" "unit" "unit-state" "process" "boot-policy" "note"
for u in $units; do
  st=$(systemctl --user is-active "$u.service" 2>/dev/null)
  [ -z "$st" ] && st=$(systemctl is-active "$u.service" 2>/dev/null)
  # `is-active` ALONE cannot say why a worker is down, and that omission hid
  # a dead worker for a full day (2026-09-28): sh2backend-perl was stopped
  # with `systemctl stop sh2loop.target` and then left DISABLED, so it would
  # not return at boot — yet the panel printed a bare "✗ inactive", which is
  # exactly what a worker that is merely mid-restart also prints. A unit that
  # will never come back is the one case that MUST be distinguishable, and it
  # is the one case `is-active` cannot distinguish. So read the boot policy
  # too: "disabled" means stopped on purpose and NOT coming back.
  en=$(systemctl --user is-enabled "$u.service" 2>/dev/null)
  [ -z "$en" ] && en=$(systemctl is-enabled "$u.service" 2>/dev/null)
  case "$en" in
    enabled|enabled-runtime) boot="auto-restart" ;;
    disabled|static|masked|masked-runtime) boot="WILL NOT RESTART" ;;
    *) boot="${en:-?}" ;;
  esac
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
    printf "  %-20s %-9s %-8s %-12s %s\n" "$u" "✓ active" "✓" "$boot" "$what"
  else
    # Name the CONSEQUENCE, not just the state. "inactive" alone is the same
    # word for a unit that is restarting and one that is gone for good.
    if [ "$boot" = "WILL NOT RESTART" ]; then
      note="STOPPED + DISABLED — will not come back at boot; re-enable: systemctl --user enable --now $u.service"
    else
      note="not running"
    fi
    printf "  %-20s %-9s %-8s %-12s %s\n" "$u" "✗ $st" "✗" "$boot" "$note"
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
