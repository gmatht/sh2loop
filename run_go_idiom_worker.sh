#!/usr/bin/env bash
# run_go_idiom_worker.sh — the idiom-triage worker (TRANSLATE_ONE_APPLICATION
# mining loop): on demand, mine NEW Go idioms from our own Go frontends (the
# source applications) and grow the Go idiom ladder.
#
# Roles (per the playbook):
#   deterministic gap scan   construct inventory -> uncovered list (ranked
#                            by app frequency); the ladder = templates/go/*.sig
#   AI (idiom-triage)        only at the classification/synthesis fork:
#                            one minimal hermetic probe per uncovered
#                            construct + a gap-class verdict
#   fix loop                 FRONTEND-GAP -> setup_backends.sh --pi-fix-frontend go-sh
#                            BOUNDARY     -> core-requests/ (structured request)
#   no-regression guard      fail-go --gate + make test green before any commit
#
# Triggers (on demand):  touch .go-idiom-trigger  (the loop checks each cycle)
#                        ./run_go_idiom_worker.sh --once
#                        ./run_go_idiom_worker.sh --watch N  (periodic)
#
# Scope: frontends/go-sh/ + harness/ + fail-go + core-requests/ escalations.
# NEVER the shared core (shir.rs/ir.rs/estree.rs/parser/) — boundaries are
# escalated, not forked. templates/go/ is gitignored worker output (the
# ladder lives there; regenerable via translate_one_application.sh
# dump-templates --lang go).
set -euo pipefail
cd "$(dirname "$0")"
WORKSPACE="$(pwd)"
LOG="$WORKSPACE/loop-go-idiom-worker.log"
TPLDIR="$WORKSPACE/templates/go"
PROBES="$WORKSPACE/.go-idiom-work"
MODEL="${MODEL:-deepseek-v4-flash}"
THINKING="${THINKING:-xhigh}"
WATCH="${WATCH:-600}"           # seconds between periodic passes
MAX_NEW="${MAX_NEW:-6}"         # constructs per pass (the cap protects the oracle)
APPS="${APPS:-frontends/*/*.go}"
# the source APPLICATIONS themselves (the playbook's final integration
# test): when the ladder covers the mined idioms, try to transpile these
APP_FILES="${APP_FILES:-frontends/go-sh/cmd/go-sh/main.go frontends/go-sh/go-sh.go}"
SEEN="$PROBES/seen"

# Worker cgroup enrollment (harness/WorkerPool.pm): runs inside sh2workers.
perl "$WORKSPACE/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
mkdir -p "$TPLDIR" "$PROBES/probes" "$PROBES/known"

# ── the construct inventory (Go idioms ranked by app frequency) ───────
# Rows: PATTERN|label. The scan counts hits across the app sources and
# flags any pattern with no covering templates/go/<label>.sig (or whose
# ERE appears in none of the existing sigs).
declare -a INVENTORY=(
  'strings\.Join|join'
  'strings\.Index|str_index'
  'strings\.Split|str_split'
  'strings\.TrimPrefix|str_prefix'
  'strings\.TrimSuffix|str_suffix'
  'strings\.HasSuffix|str_suffix'
  'strings\.Builder|builder'
  'strings\.ToUpper|str_upper'
  'strings\.ToLower|str_lower'
  'strings\.Replace|str_replace'
  'bytes\.Buffer|builder'
  '\[\]byte|byte_slice'
  '\[\]int|array_lit'
  '\[\]string|array_lit'
  'make\(\[\]|array_append'
  '\.Append|array_append'
  'map\[.*\]|map_lit'
  'for .*range|for_range'
  'for [A-Za-z_]+ := [0-9]+;|for_cstyle'
  '\bdefer\b|defer_stmt'
  '\.\(type\)|type_switch'
  'type .* struct|struct_type'
  'type .* interface|interface_type'
  'func\(.*\).*\(|func_arg'
  'err != nil|err_check'
  ', err :=|err_check'
  '\bnil\b|nil_check'
  'strconv\.[A-Z]|strconv_num'
  'fmt\.Errorf|erroref'
  'fmt\.Sprintf|sprintf'
  'sort\.|sort_pkg'
  'filepath\.|filepath'
  'exec\.Command|exec_cmd'
  'os\.Getenv|env_get'
  'os\.Setenv|env_set'
  'os\.WriteFile|write_file'
  'os\.ReadFile|read_file'
  'os\.Stat|file_test'
  'os\.Args|args'
  'bufio\.|stdin_read'
  '\.Output\(\)|exec_cmd'
  '\.Run\(\)|exec_cmd'
  '\bbreak\b|break_loop'
  '\bcontinue\b|continue_loop'
  '\breturn\b|return_val'
  'switch |switch'
  '\+\+|incr'
  '\+=|incr'
  ':=|assign'
)

gap_scan() {  # -> "hits|label|pattern" lines for uncovered constructs
  local hits pat label covered sig
  for row in "${INVENTORY[@]}"; do
    pat="${row%%|*}"; label="${row##*|}"
    covered=0
    if [ -f "$TPLDIR/$label.sig" ]; then
      covered=1
    else
      for sig in "$TPLDIR"/*.sig; do
        [ -f "$sig" ] || continue
        if grep -qE "$pat" "$sig" 2>/dev/null; then covered=1; break; fi
      done
    fi
    [ "$covered" = 1 ] && continue
    hits=0
    for f in $APPS; do
      [ -f "$f" ] || continue
      c=$(grep -cE "$pat" "$f" 2>/dev/null || true)
      hits=$((hits + c))
    done
    [ "$hits" -gt 0 ] && printf '%s|%s|%s\n' "$hits" "$label" "$pat"
  done | sort -rn
}

# ── app transpile: the final integration test ────────────────────────
# When the ladder covers the mined idioms, try the APP itself (our own Go
# frontend). The first refusal is reduced to a minimal probe and routed
# through the same classify → fix/escalate path; each refusal is marked
# seen so the next pass moves to the next construct (one per pass).
app_transpile() {
  local f err ln key a1 e js native
  mkdir -p "$SEEN"
  for f in $APP_FILES; do
    [ -f "$f" ] || continue
    if ! a1=$("$WORKSPACE/frontends/go-sh/go-sh" --shir "$f" --raw 2>"$PROBES/app.err"); then
      err=$(head -1 "$PROBES/app.err" || true)
      ln=$(printf '%s' "$err" | grep -oE 'line [0-9]+' | head -1 | awk '{print $2}')
      # the seen key is the REFUSAL MESSAGE, not the line: a frontend fix
      # changes the file, and the SAME line can hold a DIFFERENT construct
      # next pass — a stale line-keyed marker would block the new gap
      key="$(basename "$f"):$(printf '%s' "$err" | md5sum | cut -c1-10)"
      [ -f "$SEEN/$key" ] && continue
      echo "[$(date +%FT%T)] idiom-triage: app $f refuses ($err) — reducing to a probe" >> "$LOG"
      {
        printf 'The Go application %s refuses to transpile:
  %s
' "$f" "$err"
        if [ -n "${ln:-}" ] && [ "$ln" -gt 0 ] 2>/dev/null; then
          printf 'Failing source line:
  '
          sed -n "${ln}p" "$f" 2>/dev/null | head -1
          printf '
'
        fi
        printf 'Write a MINIMAL hermetic probe (templates/go/<name>.sig + <name>.go) that
'
        printf 'reproduces THIS construct (one construct per probe; oracle = go run of the
'
        printf 'wrapped snippet). Classify: FRONTEND-GAP | BOUNDARY | DIVERGENCE.
'
        printf 'FRONTEND-GAP → fix it in frontends/go-sh/go-sh.go (in scope).
'
        printf 'BOUNDARY → append a structured request to core-requests/go-sh-dogfood-20260815-contract-boundaries.md.
'
        printf 'Never touch other frontends/ files or the shared core. Stage explicit paths.
'
      } > "$PROBES/prompt.txt"
      pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING"          < "$PROBES/prompt.txt" >> "$LOG" 2>&1 || true
      touch "$SEEN/$key"
      return 0   # one refusal per pass
    fi
    # renders — execute vs the oracle (main packages only)
    e=$(printf '%s' "$a1" | "$WORKSPACE/sh2perl/otranspilerl/target/debug/otranspilerl-cli" --shir-in-estree - 2>/dev/null || true)
    js=$(cd "$PROBES" && printf '%s' "$e" | timeout 20 node "$WORKSPACE/harness/estree-runner.mjs" /dev/stdin --source "$f" 2>/dev/null || true)
    native=$(cd "$PROBES" && timeout 20 go run "$WORKSPACE/$f" 2>/dev/null || true)
    if [ "$js" = "$native" ]; then
      echo "[$(date +%FT%T)] idiom-triage: app $f TRANSPILES (js == go run)" >> "$LOG"
      touch "$PROBES/app-green-$(basename "$f")"
    else
      echo "[$(date +%FT%T)] idiom-triage: app $f renders but MISMATCHES oracle — extract next" >> "$LOG"
    fi
  done
}

# ── one mining pass ───────────────────────────────────────────────────
run_pass() {
  echo "[$(date +%FT%T)] idiom-triage: gap scan (apps: $APPS)" >> "$LOG"
  local uncovered before after
  uncovered=$(gap_scan)
  if [ -z "$uncovered" ]; then
    echo "[$(date +%FT%T)] idiom-triage: ladder covers the app's dialect — nothing new" >> "$LOG"
    app_transpile
    return 0
  fi
  echo "[$(date +%FT%T)] idiom-triage: uncovered constructs:" >> "$LOG"
  printf '%s\n' "$uncovered" | head -"$MAX_NEW" | while IFS='|' read -r hits label pat; do
    echo "    $hits×  $label  ($pat)" >> "$LOG"
  done || true

  # the AI fork — probe synthesis + classification (judgment, low volume;
  # the playbook: AI enters ONLY here, every probe is verified below by the
  # deterministic oracle)
  before=$(ls "$TPLDIR"/*.go 2>/dev/null | wc -l)
  {
    printf 'You are the idiom-triage worker for the Go→JS translation pipeline.\n'
    printf 'Our OWN Go frontends (the source applications) use Go constructs the idiom\n'
    printf 'ladder (templates/go/*.sig + *.go) does not cover yet.\n\n'
    printf 'Uncovered constructs (hits = uses across the app sources):\n'
    printf '%s\n' "$uncovered" | head -"$MAX_NEW" | while IFS='|' read -r hits label pat; do
      printf '  %s×  %s  (grep ERE: %s)\n' "$hits" "$label" "$pat"
      printf '    sample app usage:\n'
      grep -rnE "$pat" $APPS 2>/dev/null | grep -vE 'testdata|_test' | head -2 | sed 's/^/      /' || true
    done
    printf '\nFor EACH uncovered construct above, deliver:\n'
    printf '  1. templates/go/<name>.sig — a grep ERE that fires when an app uses the construct\n'
    printf '  2. templates/go/<name>.go  — ONE minimal hermetic probe (deterministic stdout; no\n'
    printf '     files/network/env/timing; the oracle is `go run` of the wrapped snippet).\n'
    printf '     Use ONLY constructs the go-sh frontend already parses (the testdata corpus\n'
    printf '     and the existing ladder probes are the reference) unless you also fix the\n'
    printf '     frontend (frontends/go-sh/go-sh.go — in scope).\n'
    printf '  3. A classification line per probe: FRONTEND-GAP | BOUNDARY | DIVERGENCE.\n'
    printf '     FRONTEND-GAP = expressible in the A1; the frontend lacks the parse (fix it).\n'
    printf '     BOUNDARY     = no shell-flavored A1 shape (structs, methods, func values,\n'
    printf '                    defer...) — never force it; append a structured request to\n'
    printf '                    core-requests/go-sh-dogfood-20260815-contract-boundaries.md.\n'
    printf '     DIVERGENCE   = means something different in Go than in the contract home\n'
    printf '                    semantics (go func() races) — document only.\n\n'
    printf 'DISCIPLINE: one construct per probe; refuse > guess; the oracle is the source\n'
    printf 'native run; never touch the shared core (shir.rs/ir.rs/estree.rs/parser/);\n'
    printf 'stage explicit paths only. Write the files into templates/go/ and reply with\n'
    printf 'the classification.\n'
  } > "$PROBES/prompt.txt"
  pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING" \
     < "$PROBES/prompt.txt" >> "$LOG" 2>&1 || true
  after=$(ls "$TPLDIR"/*.go 2>/dev/null | wc -l)

  # deterministic verification: probe every NEW template; red ones stay red
  # (the fix loop + escalation below), and the whole ladder re-runs
  for sig in "$TPLDIR"/*.sig; do
    [ -f "$sig" ] || continue
    name=$(basename "$sig" .sig)
    tpl="${sig%.sig}.go"
    [ -f "$tpl" ] || continue
    [ -f "$PROBES/known/$name" ] && continue
    cp "$tpl" "$PROBES/probes/$name.go"
  done
  if [ "$(ls "$PROBES"/probes/*.go 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "[$(date +%FT%T)] idiom-triage: probing $(ls "$PROBES"/probes/*.go | wc -l) new probe(s)" >> "$LOG"
    WORK="$PROBES" "$WORKSPACE/translate_one_application.sh" probe --lang go >> "$LOG" 2>&1 || true
    for sig in "$TPLDIR"/*.sig; do
      [ -f "$sig" ] || continue
      name=$(basename "$sig" .sig)
      [ -f "$PROBES/known/$name" ] && continue
      touch "$PROBES/known/$name"
    done
  fi

  # classification + fix/escalate, gated (no-regression guard)
  if ! bash "$WORKSPACE/fail-go" --gate >> "$LOG" 2>&1; then
    echo "[$(date +%FT%T)] idiom-triage: ladder red — invoking the frontend fix agent" >> "$LOG"
    bash "$WORKSPACE/setup_backends.sh" --pi-fix-frontend go-sh >> "$LOG" 2>&1 || true
  fi
  if bash "$WORKSPACE/fail-go" --gate >> "$LOG" 2>&1 \
     && (cd "$WORKSPACE/frontends/go-sh" && make test >> "$LOG" 2>&1); then
    local changes
    changes=$(git -C "$WORKSPACE" status --porcelain 2>/dev/null \
              | awk '/^.. /{print $2}' \
              | awk '$0 ~ /^frontends\/go-sh\// || $0 ~ /^harness\// || $0 ~ /^fail-go$/' || true)
    if [ -n "$changes" ]; then
      git -C "$WORKSPACE" add $changes 2>/dev/null || true
      git -C "$WORKSPACE" commit -m "go idioms: ladder growth (frontend fixes, gate green)" >> "$LOG" 2>&1 || true
    fi
    echo "[$(date +%FT%T)] idiom-triage: pass GREEN (ladder + corpus)" >> "$LOG"
    printf '%s idiom-triage: pass GREEN (ladder %s probes + corpus)\n' "$(date +%FT%T)" "$(ls "$TPLDIR"/*.go 2>/dev/null | wc -l)" >> "$WORKSPACE/gate-reports/idiom-triage.report"
  else
    echo "[$(date +%FT%T)] idiom-triage: gate red after pass — escalated/left red (never bless a regression)" >> "$LOG"
    printf '%s idiom-triage: gate RED (ladder %s probes + corpus)\n' "$(date +%FT%T)" "$(ls "$TPLDIR"/*.go 2>/dev/null | wc -l)" >> "$WORKSPACE/gate-reports/idiom-triage.report"
  fi
}

# ── entry ─────────────────────────────────────────────────────────────
ONCE=0
for a in "$@"; do
  case "$a" in
    --once) ONCE=1 ;;
    --watch) WATCH="${2:-$WATCH}"; shift ;;
    --apps) shift; APPS="$1" ;;
    -h|--help) sed -n '1,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

if [ "$ONCE" = 1 ]; then
  run_pass
  exit 0
fi

echo "[$(date +%FT%T)] idiom-triage worker started (pid=$$, watch=$WATCH s, apps: $APPS)" >> "$LOG"
while true; do
  if [ -f "$WORKSPACE/.go-idiom-trigger" ]; then
    echo "[$(date +%FT%T)] idiom-triage: on-demand trigger seen — running pass" >> "$LOG"
    rm -f "$WORKSPACE/.go-idiom-trigger"
  else
    echo "[$(date +%FT%T)] idiom-triage: periodic pass" >> "$LOG"
  fi
  run_pass
  sleep "$WATCH"
done
