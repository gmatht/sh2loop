#!/usr/bin/env bash
# harness/triage.sh — cross-product triage: (frontend corpus) × (backend).
#
# Every frontend gates its OWN corpus against the DEFAULT estree render;
# every backend gates the SHARED sh corpus. What nobody tests is the
# cross-product — "what does the C frontend emit, and can the GO backend
# render it?" That is where "the A1 only estree understands" bugs live.
#
# NO execution cache: every run recomputes (the emit is milliseconds, the
# node proxy ~2s/example). The point is detecting when ANY input changed
# (a core build, a frontend, a backend binary) — caching would hide it.
# The A1 is emitted ONCE per example and passed to every backend cell of
# that row (in-shell, not persisted).
#
# For a (frontend, example, backend) pair this classifies failures:
#   FAIL-FRONTEND-EMIT — the frontend refused the example.
#   FAIL-FRONTEND      — the A1 is wrong (a non-estree backend rejects it,
#                        or the estree REFERENCE also mismatches native).
#   FAIL-BACKEND       — the A1 is fine (estree matches native) but the
#                        backend panics / refuses-to-render / differs.
#   SKIP-REFUSE        — the backend's documented REFUSE > GUESS.
#   SKIP-UNWIRED       — toolchain / renderer missing.
#   PASS / PASS-RENDER — render OK (PASS = executed output matches too;
#                        PASS-RENDER = the <lang> sh2 runtime isn't ported).
#
# Verdicts are APPENDED to triage/verdicts.tsv (last row per pair wins —
# the external report + the worker's change-detection baseline):
#   frontend<TAB>backend<TAB>example<TAB>status<TAB>detail<TAB>epoch
# and summarized into triage/report.json + report.md.
#
# Usage:
#   triage.sh <frontend> <example> <backend>          # one pair
#   triage.sh --sweep [--random N] [frontends...] [backends...]
#   triage.sh --report                                # regenerate the report
#   triage.sh --clear                                 # drop the verdicts
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TRIAGE="$ROOT/triage"
VTSV="$TRIAGE/verdicts.tsv"
REPORT="$TRIAGE/report.json"
MDREPORT="$TRIAGE/report.md"
mkdir -p "$TRIAGE"

DEBASHC="$ROOT/sh2perl/target/debug/debashc"      # shared core (the estree reference)
RUNNER="$ROOT/harness/estree-runner.mjs"
NOW() { date +%s; }
NOWI() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ── the fleet tables ────────────────────────────────────────────
# frontend: corpus-dir|ext|emit-bin|native-runner("" = none)
FRONTENDS="
c-sh-go|testdata|c|./c-sh-go|compile:cc
cpp-sh-go|testdata_cpp|cc|./cpp-sh-go|compile:g++
bat-sh-go|testdata|bat|./bat-sh-go|
py-sh-go|testdata|py|./py-sh-go|run:python3
perl-sh-go|testdata|pl|./perl-sh-go|run:perl
posix-sh-go|testdata|sh|./posix-sh-go|run:bash
zsh-sh-go|testdata|zsh|./zsh-sh-go|run:zsh
fish-sh-go|testdata|fish|./fish-sh-go|run:fish
go-sh|testdata|sh,go|./go-sh|go-wrap
"
# backend: debashc-bin|flag|run("" = render-only)|label
BACKENDS="
js|$ROOT/sh2perl/backends/js/target/debug/debashc|--shir-in-js||scaffold
perl|$ROOT/sh2perl/backends/perl/target/debug/debashc|--shir-in-perl|run:perl|production
sh|$ROOT/sh2perl/backends/sh/target/debug/debashc|--shir-in-sh|run:bash|production
c|$ROOT/sh2perl/backends/c/target/debug/debashc|--shir-in-c||scaffold
go|$ROOT/sh2perl/backends/go/target/debug/debashc|--shir-in-go||scaffold
python|$ROOT/sh2perl/backends/python/target/debug/debashc|--shir-in-python||scaffold
java|$ROOT/sh2perl/backends/java/target/debug/debashc|--shir-in-java||scaffold
rust|$ROOT/sh2perl/backends/rust/target/debug/debashc|--shir-in-rust||scaffold
zig|$ROOT/sh2perl/backends/zig/target/debug/debashc|--shir-in-zig||scaffold
"

frontend_info() { echo "$FRONTENDS" | awk -F'|' -v n="$1" '$1==n {print $2"|"$3"|"$4"|"$5}'; }
backend_info() { echo "$BACKENDS" | awk -F'|' -v n="$1" '$1==n {print $2"|"$3"|"$4"|"$5}'; }

# ── the row primitives (computed ONCE per example, passed to each cell) ──
emit_a1() {  # frontend example-file -> A1 JSON on stdout (transformed)
  local fe="$1" f="$2"
  local info; info=$(frontend_info "$fe")
  IFS='|' read -r corpus ext bin native <<<"$info"
  local tmp; tmp=$(mktemp -d "$TRIAGE/.em.XXXXXX")
  ( cd "$ROOT/frontends/$fe" && "$bin" --shir "$f" --raw 2>/dev/null ) > "$tmp/a1.json" || { rm -rf "$tmp"; return 1; }
  # c/cpp: the out-param transform (the frontend gates apply it before ingress)
  if [ "$ext" = c ] || [ "$ext" = cc ]; then
    python3 "$ROOT/harness/outparam_to_returns.py" < "$tmp/a1.json" > "$tmp/a1b.json" 2>/dev/null \
      && mv "$tmp/a1b.json" "$tmp/a1.json"
  fi
  cat "$tmp/a1.json"
  rm -rf "$tmp"
}
native_out() {  # frontend example-file -> native stdout ("" = none: bat)
  local fe="$1" f="$2"
  local info; info=$(frontend_info "$fe")
  IFS='|' read -r corpus ext bin native <<<"$info"
  [ -z "$native" ] && return 0
  local mode cmd
  IFS=':' read -r mode cmd <<<"$native"
  if [ "$mode" = run ]; then
    ( cd "$ROOT/frontends/$fe" && timeout 20 "$cmd" "$f" ) < /dev/null 2>/dev/null || true
  elif [ "$mode" = go-wrap ]; then
    # Go-flavored sh: wrap into a runnable program (frontend-stdout's go mode)
    local tmp; tmp=$(mktemp -d "$TRIAGE/.nat.XXXXXX")
    if grep -q 'func main()' "$f"; then cp "$f" "$tmp/main.go";
    else
      local imports=""
      grep -q 'fmt\.'  "$f" && imports="$imports\n\t\"fmt\""
      grep -q 'exec\.' "$f" && imports="$imports\n\t\"os/exec\""
      { printf 'package main\n\nimport (\n%b\n)\n\nfunc main() {\n' "$imports"; cat "$f"; printf '\n}\n'; } > "$tmp/main.go"
    fi
    ( cd "$tmp" && timeout 20 go run main.go ) < /dev/null 2>/dev/null || true
    rm -rf "$tmp"
  else
    local tmp; tmp=$(mktemp -d "$TRIAGE/.nat.XXXXXX")
    ( cd "$tmp" && cp "$f" main.$ext && timeout 20 "$cmd" main.$ext -o main 2>/dev/null \
      && timeout 20 ./main ) < /dev/null 2>/dev/null || true
    rm -rf "$tmp"
  fi
}
estree_ref_out() {  # a1-file -> the estree-proxy executed output
  local a1="$1"
  "$DEBASHC" --shir-in-estree "$a1" > "$TRIAGE/.ref.estree.json" 2>/dev/null || return 1
  timeout 30 node "$RUNNER" "$TRIAGE/.ref.estree.json" 2>/dev/null || true
}
backend_out() {  # backend run-field rendered-file -> executed output
  local run="$1" rendered="$2"
  [ -z "$run" ] && { echo ""; return 0; }
  local mode cmd
  IFS=':' read -r mode cmd <<<"$run"
  if [ "$mode" = run ]; then
    timeout 20 "$cmd" "$rendered" 2>/dev/null || true
  else
    local tmp; tmp=$(mktemp -d "$TRIAGE/.be.XXXXXX")
    ( cd "$tmp" && cp "$rendered" main.b && timeout 20 "$cmd" main.b -o main 2>/dev/null \
      && timeout 20 ./main ) < /dev/null 2>/dev/null || true
    rm -rf "$tmp"
  fi
}
norm() { printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

record() {  # frontend backend example status detail
  local det; det=$(printf '%s' "$5" | tr '\n\t' '  ')
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$det" "$(NOW)" >> "$VTSV"
}

# ── the classifier: everything row-constant is passed in ───────
classify_pair() {  # fe ex be a1-file native-out proxy-out
  local fe="$1" ex="$2" be="$3" a1f="$4" nout="$5" pout="$6"
  local binf; binf=$(backend_info "$be"); [ -z "$binf" ] && { echo "SKIP-UNWIRED no-backend $be"; return; }
  IFS='|' read -r bdeb bflag brun blabel <<<"$binf"
  [ -x "$bdeb" ] || { echo "SKIP-UNWIRED no-renderer $bdeb"; return; }

  local work="$TRIAGE/.pair.$$"
  rm -rf "$work"; mkdir -p "$work"

  # render through the backend
  if ! "$bdeb" "$bflag" "$a1f" > "$work/rendered" 2>"$work/render.err"; then
    local err; err=$(head -c 160 "$work/render.err")
    if echo "$err" | grep -qiE "refuse|unsupported|not supported|not wired|subset"; then
      record "$fe" "$be" "$ex" "SKIP-REFUSE" "$err"; echo "SKIP-REFUSE $fe/$ex/$be ($err)"
    else
      record "$fe" "$be" "$ex" "FAIL-BACKEND" "render failed: $err"
      echo "FAIL-BACKEND $fe/$ex/$be (render failed: $err)"
    fi
    rm -rf "$work"; return
  fi
  if head -c 120 "$work/rendered" | grep -qiE "refuse|unsupported"; then
    record "$fe" "$be" "$ex" "SKIP-REFUSE" "$(head -c 120 "$work/rendered")"
    echo "SKIP-REFUSE $fe/$ex/$be ($(head -c 80 "$work/rendered"))"
    rm -rf "$work"; return
  fi

  # render-only backends (the <lang> sh2 runtime isn't ported yet)
  if [ -z "$brun" ]; then
    record "$fe" "$be" "$ex" "PASS-RENDER" "render OK; execute needs the sh2 $be runtime"
    echo "PASS-RENDER $fe/$ex/$be (render OK; execute needs the sh2 $be runtime)"
    rm -rf "$work"; return
  fi

  # executed comparison + ownership disambiguation
  local bo; bo=$(backend_out "$brun" "$work/rendered")
  local nnorm enorm bnorm
  nnorm=$(norm "$nout"); enorm=$(norm "$pout"); bnorm=$(norm "$bo")
  # bat has no native — the estree reference IS the oracle
  [ -z "$nnorm" ] && [ "$be" != estree ] && nnorm="$enorm"
  if [ "$bnorm" = "$nnorm" ]; then
    record "$fe" "$be" "$ex" "PASS" "native match"
    echo "PASS $fe/$ex/$be"
  elif [ "$enorm" = "$nnorm" ]; then
    record "$fe" "$be" "$ex" "FAIL-BACKEND" "estree matches native; $be differs"
    echo "FAIL-BACKEND $fe/$ex/$be (estree matches native, $be differs)"
  else
    record "$fe" "$be" "$ex" "FAIL-FRONTEND" "estree reference also mismatches native"
    echo "FAIL-FRONTEND $fe/$ex/$be (estree reference also mismatches)"
  fi
  rm -rf "$work"
}

# ── the sweep: (frontend, example) OUTER — the row once, backends inner ──
list_frontends() { echo "$FRONTENDS" | awk -F'|' '$1!="" {print $1}'; }
list_backends() { echo "$BACKENDS" | awk -F'|' '$1!="" {print $1}'; }
list_examples() {
  local info; info=$(frontend_info "$1")
  IFS='|' read -r corpus ext bin native <<<"$info"
  local e; for e in ${ext//,/ }; do
    ls "$ROOT/frontends/$1/$corpus"/*."$e" 2>/dev/null
  done | xargs -n1 basename | grep -vE '_refuse|_gap'
  # *_refuse* / *_gap* files are REFUSAL PINS: the frontend must FAIL to
  # emit them (each frontend gate asserts exactly that — the cpp gate's
  # "refusals: *_refuse.cc must FAIL loudly"). Triage's cross-product
  # tests the A1 a frontend EMITS; a refusal pin emits nothing, so its
  # expected emit-failure is not a FAIL-FRONTEND-EMIT and must never be
  # escalated as a broken frontend (the 2026-08-13 false pi-fix session
  # came from exactly that). Same *_gap* convention as coverage-gap.sh.
}

sweep() {
  local random_n=0
  local fes=() bes=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --random) random_n="$2"; shift 2 ;;
      *) fes+=("$1"); shift ;;
    esac
  done
  [ ${#fes[@]} -eq 0 ] && fes=($(list_frontends))
  [ ${#bes[@]} -eq 0 ] && bes=($(list_backends))

  local pairs=() fe ex be
  # the deterministic sweep
  for fe in "${fes[@]}"; do
    for ex in $(list_examples "$fe"); do
      for be in "${bes[@]}"; do pairs+=("$fe|$ex|$be"); done
    done
  done
  # the random complement (breaks ordering bias, covers the untested space)
  local i
  for i in $(seq 1 "$random_n"); do
    local rfe rex
    rfe=$(list_frontends | shuf -n1); rex=$(list_examples "$rfe" | shuf -n1)
    pairs+=("$rfe|$rex|$(list_backends | shuf -n1)")
  done

  echo "sweep: ${#pairs[@]} pairs (${#fes[@]} frontends × ${#bes[@]} backends, +$random_n random)"
  local p last_fe="" last_ex="" a1f="" nout="" pout=""
  for p in "${pairs[@]}"; do
    IFS='|' read -r fe ex be <<<"$p"
    # the row: emit A1, native, and the estree-proxy ONCE per (frontend, example)
    if [ "$fe" != "$last_fe" ] || [ "$ex" != "$last_ex" ]; then
      last_fe="$fe"; last_ex="$ex"
      local example="$ROOT/frontends/$fe/$(frontend_info "$fe" | cut -d'|' -f1)/$ex"
      a1f=$(mktemp -d "$TRIAGE/.row.XXXXXX")
      if emit_a1 "$fe" "$example" > "$a1f/a1.json" 2>/dev/null; then
        nout=$(native_out "$fe" "$example")
        pout=$(estree_ref_out "$a1f/a1.json" || true)
      else
        nout=""; pout=""
      fi
    fi
    if [ -s "$a1f/a1.json" ]; then
      classify_pair "$fe" "$ex" "$be" "$a1f/a1.json" "$nout" "$pout"
    else
      record "$fe" "$be" "$ex" "FAIL-FRONTEND-EMIT" "frontend refused the example"
      echo "FAIL-FRONTEND-EMIT $fe/$ex/$be (frontend refused)"
    fi
  done
}

# ── the external report ─────────────────────────────────────────
gen_report() {
  local generated; generated=$(NOWI)
  local total; total=$(wc -l < "$VTSV" 2>/dev/null || echo 0)
  local statuses=(PASS PASS-RENDER FAIL-FRONTEND-EMIT FAIL-FRONTEND FAIL-BACKEND SKIP-REFUSE SKIP-UNWIRED)
  {
    echo "{"
    echo "  \"generated\": \"$generated\","
    echo "  \"schema\": 1,"
    echo "  \"summary\": {"
    local s c first=1
    for s in "${statuses[@]}"; do
      c=$(awk -F'\t' -v s="$s" '$4==s {n++} END {print n+0}' "$VTSV" 2>/dev/null)
      [ "$first" = 1 ] || echo "    ,"
      echo "    \"$s\": $c"
      first=0
    done
    echo "    ,\"total\": $total"
    echo "  },"
    # last row per (frontend, backend, example) — the latest verdict
    echo "  \"pairs\": ["
    local first2=1 fe be ex st dt ep
    awk -F'\t' '{k=$1"\t"$2"\t"$3; if (seen[k]) { rows[lastrow[k]]=""; } rows[k]=$0; lastrow[k]=k; seen[k]=1; if (rows[k]=="") rows[k]=$0} END {for (k in rows) if (rows[k]!="") print rows[k]}' "$VTSV" 2>/dev/null | while IFS=$'\t' read -r fe be ex st dt ep; do
      [ "$first2" = 1 ] || echo "    ,"
      printf '    {"frontend":"%s","backend":"%s","example":"%s","status":"%s","detail":"%s","epoch":%s}\n' \
        "$fe" "$be" "$ex" "$st" "${dt:-}" "${ep:-0}"
      first2=0
    done
    echo "  ]"
    echo "}"
  } > "$REPORT"
  {
    echo "# Cross-product triage report"
    echo
    echo "Generated $generated · $total verdict rows · schema 1"
    echo
    echo "| status | count |"
    echo "|---|---|"
    local s c
    for s in "${statuses[@]}"; do
      c=$(awk -F'\t' -v s="$s" '$4==s {n++} END {print n+0}' "$VTSV" 2>/dev/null)
      [ "$c" -gt 0 ] && echo "| $s | $c |"
    done
    echo
    echo "## FAIL-BACKEND (the A1 is fine — estree matches native — the backend differs)"
    awk -F'\t' '$4=="FAIL-BACKEND" {print "- " $1 "/" $3 " → " $2 ": " $5}' "$VTSV" 2>/dev/null | head -40 || true
    echo
    echo "## FAIL-FRONTEND (estree reference also mismatches — the frontend's A1)"
    awk -F'\t' '$4=="FAIL-FRONTEND" {print "- " $1 "/" $3 " → " $2 ": " $5}' "$VTSV" 2>/dev/null | head -40 || true
  } > "$MDREPORT"
  echo "report: $REPORT + $MDREPORT ($total verdict rows)"
}

# ── dispatch ────────────────────────────────────────────────────
case "${1:-}" in
  --list-backends) list_backends; exit 0 ;;
  --sweep) shift; sweep "$@" ;;
  --report) gen_report ;;
  --clear) # destructive: wipes the verdict store the worker + GUI read.
    # Require --yes so a casual test can't destroy real triage data.
    if [ "${2:-}" != "--yes" ]; then
      echo "triage: --clear deletes verdicts.tsv + the reports — pass --yes to confirm" >&2
      exit 2
    fi
    rm -f "$VTSV" "$REPORT" "$MDREPORT"; echo "cleared $TRIAGE" ;;
  *)
    [ $# -eq 3 ] || { echo "usage: triage.sh <frontend> <example> <backend> | --sweep [--random N] [fes...] [bes...] | --report | --clear | --list-backends" >&2; exit 2; }
    # a single pair: compute the row inline
    info=$(frontend_info "$1")
    example="$ROOT/frontends/$1/$(echo "$info" | cut -d'|' -f1)/$2"
    a1f=$(mktemp -d "$TRIAGE/.row.XXXXXX")
    if emit_a1 "$1" "$example" > "$a1f/a1.json" 2>/dev/null; then
      nout=$(native_out "$1" "$example")
      pout=$(estree_ref_out "$a1f/a1.json" || true)
      classify_pair "$1" "$2" "$3" "$a1f/a1.json" "$nout" "$pout"
    else
      record "$1" "$3" "$2" "FAIL-FRONTEND-EMIT" "frontend refused the example"
      echo "FAIL-FRONTEND-EMIT $1/$2/$3 (frontend refused)"
    fi
    rm -rf "$a1f"
    ;;
esac
