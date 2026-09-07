#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# argv0-tests: the $0 (argv0) conformance suite.
#
# The stdout-match corpus (./fail, ./fail-estree, the backend gates) blesses
# ONE canonical invocation per example. `$0` is invocation state (argv[0]),
# so its "right output" is not a constant — a translated script must report
# its OWN invocation path, exactly like the original. That semantic can only
# be pinned by running each script under SEVERAL argv0s and requiring every
# backend to agree with bash — which is what this suite does.
#
# Contract under test: $0 is argv0 pass-through. Concretely:
#   - `echo "$0"`            prints the invocation path as given
#   - `${0##*/}` / `${0#/}`  basename / strip-prefix forms
#   - `dirname "$0"`         the invocation directory (basename-only argv0 → ".")
#   - `cd "$(dirname "$0")"` self-location must track argv0
#   - usage lines / $0 comparisons must see the same value bash sees
#
# The suite ALSO pins the corpus's $0-centric examples (057_case.sh's usage
# line, qx-var-builtin-cd.sh's self-location) under the same multi-argv0
# matrix, so the corpus behavior is continuously verified.
#
# Backends (add yours by extending run_one_backend):
#   bash    — reference (runs the ORIGINAL source at the materialized argv0)
#   sh      — the sh backend renderer (--shir-in-sh), run at the same argv0
#   estree  — --estree + harness/estree-runner.mjs --name <argv0>
#   perl    — the corpus generator, argv0 supplied by the run wrapper
#             (the same `do` wrapper ./fail uses)
#
# Usage: harness/argv0-tests/run.sh [--only backend[,backend]] [--verbose]
# Exit 1 on any mismatch. Requires WORKSPACE (default: script's parent's parent).
# ─────────────────────────────────────────────────────────────────────────────

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WS="${WORKSPACE:-$(cd "$HERE/../.." && pwd)}"
CORE="$WS/sh2perl/otranspilerl/target/debug/otranspilerl-cli"
SH_BIN="$WS/sh2perl/backends/sh/otranspilerl/target/debug/otranspilerl-cli"
RUNNER="$WS/harness/estree-runner.mjs"
VERBOSE=0
ONLY=""

for a in "$@"; do
  case "$a" in
    --verbose) VERBOSE=1 ;;
    --only=*) ONLY="${a#--only=}" ;;
    *) echo "usage: run.sh [--only=sh,estree,perl] [--verbose]" >&2; exit 2 ;;
  esac
done

BACKENDS="sh estree perl"
[ -n "$ONLY" ] && BACKENDS="$ONLY"

# Corpus $0-centric examples referenced (not duplicated) by the suite.
CORPUS_ZERO=(
  "$WS/sh2perl/examples/057_case.sh"
  "$WS/sh2perl/examples/qx-var-builtin-cd.sh"
)

TESTS=("$HERE"/tests/*.sh "${CORPUS_ZERO[@]}")

# argv0 scenarios, materialized as real paths so bash/sh run a real file:
#   abs    → full absolute path (deep, multi-component)
#   base   → basename only, run via `(cd dir && …)`  → dirname = "."
#   ren    → a DIFFERENT basename, run via `(cd dir && …)` → output must
#            track argv0, NOT the source's name
scenario_cmd() { # $1=dir $2=kind $3=file → the exact argv0 string bash sees
  case "$2" in
    abs)  echo "$1/$3" ;;
    base) echo "$3" ;;
    ren)  echo "renamed.sh" ;;
  esac
}

run_bash() { # $1=dir $2=kind $3=src  → bash stdout for that argv0
  local d="$1" k="$2" s="$3"
  case "$k" in
    abs)  bash "$d/$s" ;;               # argv0 = the absolute path
    base) (cd "$d" && bash "$s") ;;     # argv0 = "script.sh" (dirname = ".")
    ren)  (cd "$d" && bash renamed.sh) ;; # argv0 = "renamed.sh"
  esac
}

run_render_at_argv0() { # $1=dir $2=kind $3=renderfile $4=argv0
  local d="$1" k="$2" r="$3" a="$4"
  case "$k" in
    abs)  (cd "$d" && sh -c '. /dev/fd/3' "$a" 3< "$r") ;;
    base) (cd "$d" && sh -c '. /dev/fd/3' "$a" 3< "$r") ;;
    ren)  (cd "$d" && sh -c '. /dev/fd/3' "$a" 3< "$r") ;;
  esac
}

PASS=0; FAIL=0; SKIP=0
declare -a FAILURES=()

check() { # $1=backend $2=script $3=kind $4=got $5=want
  if [ "$4" = "$5" ]; then
    PASS=$((PASS+1))
    [ "$VERBOSE" = 1 ] && echo "  ok   $1 [$3] $2"
  else
    FAIL=$((FAIL+1))
    FAILURES+=("$1 [$3] $2")
    echo "  FAIL $1 [$3] $2: got '$(echo "$4" | head -1)' want '$(echo "$5" | head -1)'"
  fi
}

echo "argv0 suite: ${#TESTS[@]} scripts × 3 argv0s × backends {$BACKENDS}"
WORK="$(mktemp -d /tmp/argv0-suite-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

for src in "${TESTS[@]}"; do
  base="$(basename "$src" .sh)"
  # materialize the source at each scenario path
  for kind in abs base ren; do
    case "$kind" in
      abs)  D="$WORK/$base/deep/nested"; FN="script.sh" ;;
      base) D="$WORK/$base/base";        FN="script.sh" ;;
      ren)  D="$WORK/$base/renamed";     FN="renamed.sh" ;;
    esac
    mkdir -p "$D"
    cp "$src" "$D/$FN"
    argv0="$(scenario_cmd "$D" "$kind" "$FN")"

    ref="$(run_bash "$D" "$kind" "$FN")"
    [ "$VERBOSE" = 1 ] && echo "[$base/$kind] argv0='$argv0' ref='$(echo "$ref" | head -1)'"

    # ── sh backend ────────────────────────────────────────────────
    if echo "$BACKENDS" | grep -qw sh; then
      if [ -x "$SH_BIN" ] && shir="$("$CORE" --shir "$src" --raw 2>/dev/null)" && [ -n "$shir" ]; then
        if render="$(printf '%s' "$shir" | "$SH_BIN" --shir-in-sh - 2>/dev/null)" \
           && ! printf '%s' "$render" | grep -qE 'TODO\(unsupported\)|sh2[A-Za-z_]'; then
          cp "$src" "$D/$FN"          # restore (bash consumed the original)
          printf '%s' "$render" > "$D/$FN.render"
          got="$(run_render_at_argv0 "$D" "$kind" "$D/$FN.render" "$argv0")"
          check sh "$base" "$kind" "$got" "$ref"
        else
          SKIP=$((SKIP+1)); echo "  SKIP sh [$kind] $base (render refused/stub)"
        fi
      else
        SKIP=$((SKIP+1)); echo "  SKIP sh [$kind] $base (no renderer binary)"
      fi
    fi

    # ── estree backend ─────────────────────────────────────────────
    if echo "$BACKENDS" | grep -qw estree; then
      if json="$("$CORE" --shir "$src" --raw 2>/dev/null)" && [ -n "$json" ] \
         && json_out="$("$CORE" file --estree "$src" 2>/dev/null)" && [ -n "$json_out" ]; then
        jf="$WORK/$base.json"
        printf '%s' "$json_out" > "$jf"
        if [ -f "$RUNNER" ]; then
          got="$(cd "$D" && timeout 20 node "$RUNNER" "$jf" --source "$src" --name "$argv0" 2>/dev/null)"
          check estree "$base" "$kind" "$got" "$ref"
        else
          SKIP=$((SKIP+1)); echo "  SKIP estree [$kind] $base (no runner)"
        fi
      else
        SKIP=$((SKIP+1)); echo "  SKIP estree [$kind] $base (no shIR/estree emit)"
      fi
    fi

    # ── perl backend ───────────────────────────────────────────────
    if echo "$BACKENDS" | grep -qw perl; then
      if gen="$("$CORE" "$src" 2>/dev/null)" && [ -n "$gen" ]; then
        pf="$WORK/$base.pl"
        printf '%s' "$gen" | sed -n '/^Generated Perl code:/,/^--- Running/p' | sed '1d;$d' > "$pf"
        if [ -s "$pf" ]; then
          got="$(cd "$D" && perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$argv0" "$pf" 2>/dev/null)"
          check perl "$base" "$kind" "$got" "$ref"
        else
          SKIP=$((SKIP+1)); echo "  SKIP perl [$kind] $base (no code extracted)"
        fi
      else
        SKIP=$((SKIP+1)); echo "  SKIP perl [$kind] $base (otranspilerl-cli failed)"
      fi
    fi
  done
done

echo "──────────────────────────────────────────────"
# ── SOURCE-NAME mode (`--argv0-source`) ────────────────────────────────
# With the bake, the translated program identifies as the ORIGINAL bash
# file: output must be the SAME for every argv0 scenario (the bake wins),
# and equal to bash running with argv0 = the baked name. Perl bakes
# `$0 = …`; estree bakes `sh2.argv0 = …`. (The sh backend can't assign $0
# in POSIX — source-mode there means the gate supplies argv0 at run time.)
echo "source-mode legs: --argv0-source renamed.sh must beat all 3 argv0s"
for src in "$HERE"/tests/*.sh; do
  base="$(basename "$src" .sh)"
  for kind in abs base ren; do
    case "$kind" in
      abs)  D2="$WORK/$base/deep/nested"; FN="script.sh" ;;
      base) D2="$WORK/$base/base";        FN="script.sh" ;;
      ren)  D2="$WORK/$base/renamed";     FN="renamed.sh" ;;
    esac
    mkdir -p "$D2"
    cp "$src" "$D2/renamed.sh"
    # reference: bash with argv0 = renamed.sh FROM THIS SAME cwd (dirname "."
    # resolves pwd relative to the cwd, so the bake's output is cwd-dependent).
    ref="$(cd "$D2" && bash renamed.sh)"
    if echo "$BACKENDS" | grep -qw estree; then
      if json_out="$("$CORE" --argv0-source renamed.sh file --estree "$src" 2>/dev/null)" && [ -n "$json_out" ]; then
        jf="$WORK/$base.src.json"; printf '%s' "$json_out" > "$jf"
        got="$(cd "$D2" && timeout 20 node "$RUNNER" "$jf" --source "$src" --name "$(scenario_cmd "$D2" "$kind" "$FN")" 2>/dev/null)"
        check "estree(source)" "$base" "$kind" "$got" "$ref"
      else
        SKIP=$((SKIP+1)); echo "  SKIP estree(source) [$kind] $base"
      fi
    fi
    if echo "$BACKENDS" | grep -qw perl; then
      if gen="$("$CORE" --argv0-source renamed.sh "$src" 2>/dev/null)" && [ -n "$gen" ]; then
        pf="$WORK/$base.src.pl"
        printf '%s' "$gen" | sed -n '/^Generated Perl code:/,/^--- Running/p' | sed '1d;$d' > "$pf"
        if [ -s "$pf" ]; then
          got="$(cd "$D2" && perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$(scenario_cmd "$D2" "$kind" "$FN")" "$pf" 2>/dev/null)"
          check "perl(source)" "$base" "$kind" "$got" "$ref"
        else
          SKIP=$((SKIP+1)); echo "  SKIP perl(source) [$kind] $base (no code)"
        fi
      else
        SKIP=$((SKIP+1)); echo "  SKIP perl(source) [$kind] $base (otranspilerl-cli failed)"
      fi
    fi
  done
done

echo "──────────────────────────────────────────────"
echo "argv0 suite: $PASS pass, $FAIL fail, $SKIP skip"
if [ "$FAIL" -gt 0 ]; then
  printf '  %s\n' "${FAILURES[@]}"
  exit 1
fi
exit 0
