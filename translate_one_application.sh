#!/usr/bin/env bash
# translate_one_application.sh — TRANSLATE_ONE_APPLICATION.md as a runnable loop.
#
# Grows the translation pipeline for ONE app: mine the app's construct
# footprint -> emit minimal probe templates -> run the oracle (source-native
# vs target) -> drive pi (default model deepseek-v4-turbo) to fix red probes
# -> gate (ladder + acceptance tests). Implements the playbook's discipline:
# one construct per probe, refuse > guess, no-regression guard, escalate via
# core-requests, never `git add .`.
#
# Usage:
#   ./translate_one_application.sh mine  <app> [--lang L] [--work DIR]
#   ./translate_one_application.sh probe  [--lang L] [--work DIR]
#   ./translate_one_application.sh fix    [--lang L] [--work DIR] [--commit]
#   ./translate_one_application.sh gate   [--lang L] [--work DIR] [--tests DIR]
#   ./translate_one_application.sh run    <app> [--lang L] [--target estree|perl|c|sh]
#                                        [--tests DIR] [--iterations N] [--commit]
#   ./translate_one_application.sh dump-templates --lang L
#
# Language: detected from the app extension (sh|zsh|fish|py|pl|go) or --lang.
#   c   -> cc + frontends/c-sh-go        (C subset)
#   sh  -> bash + frontends/posix-sh-go  (byte-equality oracle)
#   zsh -> zsh  + frontends/zsh-sh-go    (byte-eq with the subscript waiver)
#   fish-> fish + frontends/fish-sh-go
#   py  -> python3 + frontends/py-sh-go
#   pl  -> perl + frontends/perl-sh-go
#   go  -> go (wrapper) + frontends/go-sh
# Target (default estree): estree | perl | c | sh | rust  (estree executes
# end-to-end via the sh2 runner; rust renders + rustc-compiles + runs; the
# rest render only).
#
# Environment: MODEL (pi model, default deepseek-v4-turbo), THINKING,
# WORK (.translate-work), TPLDIR (templates/), MAX_ATTEMPTS (3),
# MAX_PROBES (16), TIMEOUT (20), COMMIT (0/1).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUB="$ROOT/sh2perl"
OTRANS="$SUB/../otranspilerl/target/debug/otranspilerl-cli"
OTRANS="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
RUNNER="$ROOT/harness/estree-runner.mjs"
TPLDIR="${TPLDIR:-$ROOT/templates}"
WORK="${WORK:-$ROOT/.translate-work}"
MODEL="${MODEL:-deepseek-v4-turbo}"
THINKING="${THINKING:-high}"
TARGET="${TARGET:-estree}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
MAX_PROBES="${MAX_PROBES:-16}"
TIMEOUT="${TIMEOUT:-20}"
COMMIT="${COMMIT:-0}"

# ── language table: name|ext|native|frontend-bin|byte-eq-oracle ──────
LANG_SH="sh|sh|bash|$ROOT/frontends/posix-sh-go/posix-sh-go|1"
LANG_ZSH="zsh|zsh|zsh|$ROOT/frontends/zsh-sh-go/zsh-sh-go|1"
LANG_FISH="fish|fish|fish|$ROOT/frontends/fish-sh-go/fish-sh-go|0"
LANG_PY="py|py|python3|$ROOT/frontends/py-sh-go/py-sh-go|0"
LANG_PL="pl|pl|perl|$ROOT/frontends/perl-sh-go/perl-sh-go|0"
LANG_GO="go|go|go|$ROOT/frontends/go-sh/go-sh|0"
LANG_C="c|c|cc|$ROOT/frontends/c-sh-go/c-sh-go|0"

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

lang_row() { # lang -> the table row
  case "$1" in
    sh) echo "$LANG_SH" ;; zsh) echo "$LANG_ZSH" ;; fish) echo "$LANG_FISH" ;;
    py) echo "$LANG_PY" ;; pl) echo "$LANG_PL" ;; go) echo "$LANG_GO" ;;
    *) echo "unknown language: $1" >&2; exit 2 ;;
  esac
}
detect_lang() { # file -> lang (by extension)
  case "${1##*.}" in
    sh) echo sh ;; zsh) echo zsh ;; fish) echo fish ;;
    py) echo py ;; pl) echo pl ;; go) echo go ;;
    *) echo "cannot detect language from: $1 (use --lang)" >&2; exit 2 ;;
  esac
}

# ── oracle runners ────────────────────────────────────────────────────
run_native() { # file -> stdout
  case "$SLANG" in
    sh)   timeout "$TIMEOUT" bash "$1" </dev/null 2>/dev/null ;;
    zsh)  timeout "$TIMEOUT" zsh "$1" </dev/null 2>/dev/null ;;
    fish) timeout "$TIMEOUT" fish "$1" </dev/null 2>/dev/null ;;
    py)   timeout "$TIMEOUT" python3 "$1" </dev/null 2>/dev/null ;;
    pl)   timeout "$TIMEOUT" perl "$1" </dev/null 2>/dev/null ;;
    c)    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN
      cp "$1" "$tmp/main.c"
      (cd "$tmp" && timeout "$TIMEOUT" cc main.c -o main 2>/dev/null && timeout "$TIMEOUT" ./main) </dev/null 2>/dev/null ;;
    go)   # the frontend-stdout.sh wrapper: import detection + func main
      tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN
      if grep -q 'func main(' "$1"; then
        # complete program — run as-is
        cp "$1" "$tmp/main.go"
      else
        imports=""
        grep -q 'fmt\.' "$1" && imports="$imports\n\t\"fmt\""
        grep -q 'strings\.' "$1" && imports="$imports\n\t\"strings\""
        grep -q 'bufio\.' "$1" && imports="$imports\n\t\"bufio\""
        grep -qE 'os\.(Getenv|WriteFile|Setenv|Stat|Stdin|Stdout|Stderr|ReadFile|Args)' "$1" && imports="$imports\n\t\"os\""
        grep -q 'exec\.' "$1" && imports="$imports\n\t\"os/exec\""
        grep -q 'strconv\.' "$1" && imports="$imports\n\t\"strconv\""
        grep -q 'filepath\.' "$1" && imports="$imports\n\t\"path/filepath\""
        grep -q 'bytes\.' "$1" && imports="$imports\n\t\"bytes\""
        grep -q 'sort\.' "$1" && imports="$imports\n\t\"sort\""
        grep -q 'time\.' "$1" && imports="$imports\n\t\"time\""
        { printf 'package main\n\nimport (\n%b\n)\n\nfunc main() {\n' "$imports"; cat "$1"; printf '\n}\n'; } > "$tmp/main.go"
      fi
      (cd "$tmp" && timeout "$TIMEOUT" go run main.go) </dev/null 2>/dev/null ;;
  esac
}

run_target() { # file -> target stdout; rc signals the gap class
  local a1 e
  a1=$("$FBIN" --shir "$1" --raw 2>/dev/null) || return 11   # frontend emit fail
  [ -n "$a1" ] || return 12                                   # core/refuse: nothing
  case "$TARGET" in
    estree)
      e=$(printf '%s' "$a1" | "$OTRANS" --source-lang shir --target estree - 2>/dev/null) || return 13
      timeout "$TIMEOUT" node "$RUNNER" /dev/stdin --source "$1" <<<"$e" 2>/dev/null ;;
    rust)
      e=$(printf '%s' "$a1" | "$OTRANS" - - --target rust 2>/dev/null) || return 13
      tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN
      printf '%s\n' "$e" > "$tmp/main.rs"
      (cd "$tmp" && timeout "$TIMEOUT" rustc -o main main.rs 2>/dev/null \
        && timeout "$TIMEOUT" ./main) </dev/null 2>/dev/null ;;
    perl)
      e=$(printf '%s' "$a1" | "$OTRANS" --source-lang shir --target perl - 2>/dev/null) || return 13
      timeout "$TIMEOUT" perl -e "$e" 2>/dev/null ;;
    c|sh|go|py|zig|java)
      # otranspilerl target names differ (python, not py); map them
      case "$TARGET" in py) tgt=python ;; *) tgt="$TARGET" ;; esac
      e=$(printf '%s' "$a1" | "$OTRANS" - - --target "$tgt" 2>/dev/null) || return 13
      echo "$e" ;;   # render only — execution needs the target toolchain (best-effort)
    *) echo "unknown target: $TARGET" >&2; return 14 ;;
  esac
}

probe_one() { # file -> verdict line (TAB-separated)
  local f="$1" n native tgt trc byteq=""
  n=$(basename "$f")
  [ -f "$WORK/sleeping/$n" ] && { printf '%s\tSLEEPING\n' "$n"; return; }
  native=$(run_native "$f" 2>/dev/null) || native=""
  # set -e guard: run_target returns nonzero on gap classes — capture the
  # rc as the verdict instead of letting the assignment kill the loop
  tgt=""; trc=0
  tgt=$(run_target "$f" 2>/dev/null) || trc=$?
  case "$trc" in
    0)  if [ "$native" = "$tgt" ]; then v=PASS; else v=MISMATCH; fi ;;
    11) v=EMIT-FAIL ;;   # frontend cannot parse/lower the construct
    12) v=REFUSE ;;      # frontend refused / core emitted nothing
    13) v=TARGET-ERR ;;  # shIR -> target conversion failed
    *)  v=RC-$trc ;;
  esac
  if [ "$BYTEQ" = 1 ]; then   # byte-equality oracle for sh/zsh (secondary)
    mine=$("$FBIN" --shir "$f" --raw 2>/dev/null)
    core=$("$OTRANS" --target shir "$f" 2>/dev/null)
    if [ -n "$mine" ] && [ -n "$core" ] && [ "$mine" = "$core" ]; then byteq=BEQ; else byteq=beq-diff; fi
  fi
  printf '%s\t%s\t%s\n' "$n" "$v" "$byteq"
}

# ── mining: app construct footprint -> template probes ────────────────
# Templates live in $TPLDIR/<lang>/<construct>.<ext> with a sibling
# <construct>.sig containing a grep ERE that fires when the app uses the
# construct. The miner emits a probe per fired template (deduped, capped).
mine_app() { # app file
  local app="$1" tdir="$TPLDIR/$SLANG" hits=0
  [ -d "$tdir" ] || { echo "no templates for $SLANG: $tdir (dump-templates?)" >&2; exit 3; }
  mkdir -p "$WORK/probes" "$WORK/sleeping"
  rm -f "$WORK/constructs.tsv"
  for sig in "$tdir"/*.sig; do
    [ -f "$sig" ] || continue
    local name; name=$(basename "$sig" .sig)
    local tpl="${sig%.sig}.$EXT"
    [ -f "$tpl" ] || continue
    if grep -qEf "$sig" "$app" 2>/dev/null; then
      cp "$tpl" "$WORK/probes/${name}.$EXT"
      printf '%s\t1\n' "$name" >> "$WORK/constructs.tsv"
      hits=$((hits+1))
    fi
  done
  # cap: keep the first MAX_PROBES (the signature files control priority order)
  local i=0
  for p in "$WORK"/probes/*."$EXT"; do
    [ -f "$p" ] || continue
    i=$((i+1))
    [ "$i" -gt "$MAX_PROBES" ] && rm -f "$p"
  done
  echo "mined $hits constructs ($(ls "$WORK"/probes/*."$EXT" 2>/dev/null | wc -l) probes kept) — see $WORK/constructs.tsv"
}

# ── fix: pi-driven repair of red probes ───────────────────────────────
fix_red() {
  local f v n attempts=0
  for f in "$WORK"/probes/*."$EXT"; do
    [ -f "$f" ] || continue
    n=$(basename "$f")
    [ -f "$WORK/sleeping/$n" ] && continue
    v=$(probe_one "$f" | cut -f2)
    [ "$v" = PASS ] && continue
    attempts=0
    while [ "$attempts" -lt "$MAX_ATTEMPTS" ]; do
      attempts=$((attempts+1))
      echo "── fixing $n (attempt $attempts/$MAX_ATTEMPTS, verdict $v)"
      build_fix_prompt "$f" > "$WORK/prompt.txt"
      mkdir -p "$WORK/attempts"
      pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING" \
         < "$WORK/prompt.txt" >> "$WORK/attempts/$n.$attempts.log" 2>&1 || true
      v=$(probe_one "$f" | cut -f2)
      if [ "$v" = PASS ]; then
        echo "  ✓ $n green (attempt $attempts)"
        break
      fi
    done
    if [ "$v" != PASS ]; then
      echo "  ✗ $n still $v after $MAX_ATTEMPTS — escalating"
      escalate "$f" "$v"
    fi
  done
}

build_fix_prompt() { # file
  local f="$1" n; n=$(basename "$f")
  local nat tgt
  nat=$(run_native "$f" 2>/dev/null || true)
  tgt=$(run_target "$f" 2>/dev/null || true)
  cat <<EOF
You are the fix agent for the TRANSLATE_ONE_APPLICATION loop. One probe
(construct) of the app's language footprint does not translate correctly.

PROBE: $f
$(cat "$f")

EXPECTED (source-native output):
$(printf '%s' "$nat")

ACTUAL (target output):
$(printf '%s' "$tgt")

SOURCE LANGUAGE: $SLANG    TARGET: $TARGET
Frontend: $FBIN (parse source -> A1 shIR JSON)   Core: $OTRANS

DISCIPLINE (TRANSLATE_ONE_APPLICATION.md):
- Cheapest correct lowering first: native expression < sync runtime call
  < async call < subprocess spawn.
- One construct per probe; keep the probe minimal; refuse > guess.
- Fix surface: frontends/$SLANG/ + harness/ + the target backend ONLY.
  NEVER touch the shared core (sh2perl/src/shir.rs, ir.rs, estree.rs,
  parser/). If the fix needs a core/contract change, APPEND a structured
  request to core-requests/ (NEED / WHY / MINIMAL-CORE-CHANGE /
  FAILING-CASE) and exit 0 — do not edit the core.
- NO-REGRESSION GUARD: after your fix, the previously-green probes and
  the frontend's own ladder (make test in frontends/$SLANG/) must stay
  green. Verify before finishing.
- Never 'git add .'. Stage explicit paths only.
- If the construct is a semantic divergence (source semantics differ
  from the contract's home semantics), do NOT force it — document the
  divergence and exit 0.
EOF
}

escalate() { # file verdict
  local f="$1" v="$2" n; n=$(basename "$f")
  mkdir -p "$ROOT/core-requests"
  local req="$ROOT/core-requests/$SLANG-$(date +%Y%m%d-%H%M%S).md"
  {
    echo "# $SLANG: probe $n stalled at $v (TRANSLATE_ONE_APPLICATION loop)"
    echo
    echo "## NEED"
    echo "The construct below cannot be translated within the allowed"
    echo "surface (frontends/$SLANG/ + harness/ + target). It likely needs"
    echo "a shared-core or contract change."
    echo
    echo "## FAILING-CASE"
    echo "Probe: $f"
    cat "$f"
    echo
    echo "Expected (source-native):"
    run_native "$f" 2>/dev/null || true
    echo
    echo "Actual (target):"
    run_target "$f" 2>/dev/null || true
    echo
    echo "## MINIMAL-CORE-CHANGE"
    echo "To be determined by the core owner from the failing case."
  } > "$req"
  touch "$WORK/sleeping/$n"
  echo "  escalated: $req (probe $n marked sleeping)"
}

# ── gate: ladder + acceptance tests ───────────────────────────────────
run_gate() {
  local total=0 pass=0 esc=0
  echo "=== ladder probes ==="
  for f in "$WORK"/probes/*."$EXT"; do
    [ -f "$f" ] || continue
    total=$((total+1))
    local line; line=$(probe_one "$f")
    local v; v=$(echo "$line" | cut -f2)
    [ "$v" = PASS ] && pass=$((pass+1))
    [ "$v" = SLEEPING ] && esc=$((esc+1))
    echo "  $line"
  done
  echo "ladder: $pass/$total pass ($esc escalated/queued)"
  if [ -n "${TESTS:-}" ] && [ -d "$TESTS" ]; then
    local t=0 tp=0
    echo "=== acceptance tests ($TESTS) ==="
    for tf in "$TESTS"/*; do
      [ -f "$tf" ] || continue
      t=$((t+1))
      local nat tgt
      nat=$(run_native "$tf" 2>/dev/null || true)
      tgt=$(run_target "$tf" 2>/dev/null || true)
      if [ "$nat" = "$tgt" ]; then tp=$((tp+1)); v=PASS; else v=FAIL; fi
      printf '  %s\t%s\n' "$(basename "$tf")" "$v"
    done
    echo "acceptance: $tp/$t pass"
    [ "$tp" -lt "$t" ] && return 1
  fi
  [ "$pass" -lt "$total" ] && return 1
  echo "GATE GREEN"
}

# ── the full loop ─────────────────────────────────────────────────────
run_loop() {
  local app="$1" iter=0 maxiter="${ITERATIONS:-3}"
  [ -f "$app" ] || { echo "no such app: $app" >&2; exit 1; }
  while [ "$iter" -lt "$maxiter" ]; do
    iter=$((iter+1))
    echo "════ iteration $iter ════"
    mine_app "$app"
    fix_red
    if run_gate; then
      echo "TRANSLATION COMPLETE after $iter iterations"
      break
    fi
  done
  echo "=== final state ==="
  run_gate || true
}

# ── dump templates (extendable library) ───────────────────────────────
dump_templates() {
  local tdir="$TPLDIR/$SLANG"
  mkdir -p "$tdir"
  case "$SLANG" in
    sh)
      t() { # name sig template...
        local name="$1" sig="$2" tpl="$3"
        printf '%s\n' "$sig" > "$tdir/$name.sig"
        printf '%s\n' "$tpl" > "$tdir/$name.$EXT"
      }
      t for_seq      'for .* in \$' 'for i in $(seq 1 3); do echo "i$i"; done'
      t for_list     'for .* in ' 'for w in aa bb; do echo "[$w]"; done'
      t while_loop   '^while |; while ' 'i=0; while [ $i -lt 3 ]; do echo "w$i"; i=$((i+1)); done'
      t until_loop   '^until |; until ' 'i=0; until [ $i -ge 3 ]; do echo "u$i"; i=$((i+1)); done'
      t if_elif      'elif ' 'x=2; if [ $x -eq 1 ]; then echo one; elif [ $x -eq 2 ]; then echo two; else echo other; fi'
      t case_glob    'case .* in' 'case "hello" in h*) echo star;; *l*) echo alt;; esac'
      t array_lit    '[A-Za-z_][A-Za-z0-9_]*=[(][^)]' 'a=(x y z); echo "n=${#a[@]}"'
      t array_index  '\$\{[A-Za-z_][A-Za-z0-9_]*\[[0-9]' 'a=(x y z); echo "${a[1]}"'
      t array_append '[A-Za-z_][A-Za-z0-9_]*\+=[(][^)]' 'a=(x); a+=(y); echo "${a[@]}"'
      t param_default '\$\{[A-Za-z_][A-Za-z0-9_]*:-' 'x=""; echo "${x:-def}"'
      t param_subst  '\$\{[A-Za-z_][A-Za-z0-9_]*//' 's="parrot"; echo "${s//p/r}"'
      t param_prefix '\$\{[A-Za-z_][A-Za-z0-9_]*[#%]' 's="hello"; echo "${s#he}"; echo "${s%lo}"'
      t cmdsub       '\$\(|`' 'echo "$(echo hi)"'
      t pipe         '\|' 'echo abc | tr a-z A-Z'
      t func_def     '[(][)] [{]|function ' 'f() { echo in-f; }; f'
      t test_cond    '\[\[|\[ .* \]\]' 'if [ -n "x" ]; then echo yes; fi'
      t brace        '[{][A-Za-z0-9.,]+[}]|[0-9]+[}]' 'echo pre{a,b}post'
      t arith        '\$\(\(|^\s*\(\( ' 'i=2; echo $((i * 3))'
      t heredoc      '<<' $'cat <<EOF\nhello\nEOF'
      ;;
    zsh) # a few zsh-dialect seeds (arrays are 1-based)
      t() { local name="$1" sig="$2" tpl="$3"
        printf '%s\n' "$sig" > "$tdir/$name.sig"; printf '%s\n' "$tpl" > "$tdir/$name.zsh"; }
      t for_list 'for .* in ' 'for w in aa bb; do echo "[$w]"; done'
      t while_loop '^while |; while ' 'i=0; while [ $i -lt 3 ]; do echo "w$i"; i=$((i+1)); done'
      t array_lit '=\([^)]' 'a=(x y z); echo "n=${#a[@]}"'
      t array_index '\$[A-Za-z_][A-Za-z0-9_]*\[' 'a=(x y z); echo $a[2]'
      t param_default '\$\{[A-Za-z_][A-Za-z0-9_]*:-' 'x=""; echo "${x:-def}"'
      ;;
    py|pl|fish)
      echo "no seed templates for $SLANG yet — add $tdir/<name>.$EXT + <name>.sig (see templates/README)" >&2
      ;;
    go)
      t() { local name="$1" sig="$2" tpl="$3"
        printf '%s\n' "$sig" > "$tdir/$name.sig"; printf '%s\n' "$tpl" > "$tdir/$name.go"; }
      t print        'fmt\.Print'            'fmt.Println("hello probe")'
      t assign_str   ':='                    'name := "world"
fmt.Println(name)'
      t assign_num   ':= *[0-9]'             'x := 42
fmt.Println(x)'
      t arith        '[-+*/%] *[0-9$A-Za-z_]' 'x := 1 + 2 * 3
fmt.Println(x)'
      t arith_neg    '-\w'                   'x := 7
fmt.Println(-x)'
      t incr         '(\+\+|--)'            'i := 0
i++
fmt.Println(i)'
      t str_concat   '" *\+ *"'             's := "foo" + "bar"
fmt.Println(s)'
      t str_len      'len\('                 's := "hello"
fmt.Println(len(s))'
      t if_else      '^if |else '            'x := 2
if x == 1 {
    fmt.Println("one")
} else {
    fmt.Println("other")
}'
      t for_cond     '^for .*<.*\{'          'i := 0
for i < 3 {
    fmt.Println(i)
    i++
}'
      t for_cstyle   'for [A-Za-z_]+ := '    'for i := 1; i <= 3; i++ {
    fmt.Println(i)
}'
      t switch       'switch '               'x := 2
switch x {
case 1:
    fmt.Println("one")
case 2:
    fmt.Println("two")
default:
    fmt.Println("other")
}'
      t func_literal ':= *func\(\)'         'f := func() {
    fmt.Println("in-func")
}
f()'
      t array_lit    '\[\]string\{|\[\]int\{' 'a := []string{"x", "y", "z"}
fmt.Println(len(a))
fmt.Println(a[1])'
      t array_append 'append\('              'a := []string{"x"}
a = append(a, "y")
fmt.Println(a[0], a[1])'
      t map_lit      'map\['                 'm := map[string]string{"k": "v"}
fmt.Println(m["k"])'
      t str_contains 'strings\.Contains'     's := "hello"
if strings.Contains(s, "l") {
    fmt.Println("has")
}'
      t str_replace  'strings\.ReplaceAll'   's := "parrot"
fmt.Println(strings.ReplaceAll(s, "p", "r"))'
      t env_get      'os\.Getenv'            'x := os.Getenv("X")
if x == "" {
    x = "def"
}
fmt.Println("a=" + x)'
      t exec_cmd     'exec\.Command'         'out, _ := exec.Command("echo", "hi").Output()
fmt.Println(string(out))'
      t type_switch  '\.\(type\)'          'var x interface{} = "hi"
switch v := x.(type) {
case string:
    fmt.Println("string", v)
default:
    fmt.Println("other")
}'
      t seq_range    'for [A-Za-z_]+ := [0-9]+;' 'for i := 2; i <= 4; i++ {
    fmt.Printf("n%d\n", i)
}'
      t return_val   '\breturn\b'     'f := func(x int) int {
    return x * 2
}
fmt.Println(f(3))'
      t nil_check    '\bnil\b'        'var x any = nil
if x == nil {
    fmt.Println("nil")
} else {
    fmt.Println("not nil")
}'
      t break_loop   '\bbreak\b'      'for i := 0; i < 10; i++ {
    if i == 3 {
        break
    }
    fmt.Println(i)
}'
      t continue_loop '\bcontinue\b'  'for i := 1; i <= 3; i++ {
    if i == 2 {
        continue
    }
    fmt.Println(i)
}'
      t err_check    'err != nil'       'n, err := strconv.Atoi("42")
if err != nil {
    fmt.Println("bad")
} else {
    fmt.Println(n + 1)
}'
      t builder      'strings\.Builder' 'var b strings.Builder
b.WriteString("hi")
fmt.Println(b.String())'
      ;;
  esac
  echo "templates: $(ls "$tdir"/*."$EXT" 2>/dev/null | wc -l) for $SLANG in $tdir"
}

# ── arg parsing ───────────────────────────────────────────────────────
CMD=""; APP=""
while [ $# -gt 0 ]; do
  case "$1" in
    mine|probe|fix|gate|run|dump-templates) CMD="$1";;
    --lang) shift; SLANG="$1"; IFS='|' read -r SLANG EXT NATIVE FBIN BYTEQ <<< "$(lang_row "$SLANG")";;
    --target) shift; TARGET="$1";;
    --tests) shift; TESTS="$1";;
    --iterations) shift; ITERATIONS="$1";;
    --commit) COMMIT=1;;
    --work) shift; WORK="$1";;
    -h|--help) usage;;
    *) [ -z "$APP" ] && APP="$1" || { echo "unexpected arg: $1" >&2; usage 1; };;
  esac
  shift
done
[ -n "$CMD" ] || usage 1
IFS='|' read -r SLANG EXT NATIVE FBIN BYTEQ <<< "$(lang_row "$SLANG")"
mkdir -p "$WORK/probes" "$WORK/sleeping" "$WORK/attempts"

case "$CMD" in
  mine) [ -n "$APP" ] || usage 1; mine_app "$APP" ;;
  probe)
    echo "=== probes ==="
    for f in "$WORK"/probes/*."$EXT"; do [ -f "$f" ] && probe_one "$f"; done ;;
  fix) fix_red ;;
  gate) run_gate ;;
  dump-templates) dump_templates ;;
  run) [ -n "$APP" ] || usage 1; run_loop "$APP" ;;
esac

if [ "$COMMIT" = 1 ] && [ "$CMD" = fix -o "$CMD" = run ]; then
  # scoped commit (never git add .): frontends/<lang>/ + harness whitelist
  changes=$(git -C "$ROOT" status --porcelain 2>/dev/null \
            | awk '/^.. /{print $2}' \
            | awk -v d="$ROOT/frontends/$SLANG" '$0 ~ "^"d || $0 ~ /^harness\// || $0 ~ /^templates\//' || true)
  if [ -n "$changes" ]; then
    if (cd "$ROOT" && perl fail-estree --gate >/dev/null 2>&1); then
      git -C "$ROOT" add $changes
      git -C "$ROOT" commit -m "translate-one-app $SLANG->$TARGET: ladder fixes (pi loop)" || true
    else
      echo "harness changes regress the core corpus — NOT committing (stash or review)" >&2
    fi
  fi
fi
