#!/usr/bin/env bash
# py-rust-gate — executed-stdout gate for the py frontend's RUST backend.
#
# The frontend's own gate (frontend-stdout.sh py) runs the A1 through the
# ESTree/JS backend; the Rust renderer was never exercised on this corpus,
# so a Rust-only regression (missing helper, type error, runtime panic) was
# invisible. This gate compiles and runs the Rust rendering of every
# testdata example and compares stdout with the native python3 run.
#
# Usage: harness/py-rust-gate.sh [glob]        (default testdata/*.py)
# Env:   PYDIR=...  testdata dir
#        CLI=...    otranspilerl-cli (default: otranspilerl/target/debug/...)
#        TMO=...    per-step timeout seconds (default 120)
# Exit: 0 iff every non-known-gap example matches.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIR=${PYDIR:-$ROOT/sh2perl/frontends/py-sh-go/testdata}
CLI=${CLI:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}
TMO=${TMO:-120}
glob=${1:-}
# Examples the Rust renderer cannot execute yet. Every entry is a known
# GAP, never a blessed wrong answer — the list must shrink, and the gate
# prints the count so it cannot grow silently.
KNOWNGAP=${KNOWNGAP:-'t102_dual_guard.py t103_pep695.py'}

if [ ! -x "$CLI" ]; then echo "py-rust-gate: no otranspilerl-cli at $CLI" >&2; exit 2; fi
command -v rustc >/dev/null || { echo "py-rust-gate: rustc not installed" >&2; exit 2; }
# The bigint path (t87+) renders `num_bigint::BigInt`, so generated code that
# uses it needs the crate linked: cargo compiles it for the core, and rustc
# 1.90 (the workspace toolchain) can reuse that rlib via --extern. Resolve it
# lazily: only programs whose Rust text mentions num_bigint pay for it, and a
# missing rlib is a hard error for those (never a silent skip).
BIGINT_RLIB=""
bigint_flags() { # <prog.rs> -> rustc flags on stdout (empty when not needed)
    grep -q 'num_bigint' "$1" || return 0
    if [ -z "$BIGINT_RLIB" ]; then
        BIGINT_RLIB=$(ls -t "$ROOT"/otranspilerl/target/debug/deps/libnum_bigint-*.rlib \
                         "$ROOT"/sh2perl/target/debug/deps/libnum_bigint-*.rlib 2>/dev/null | head -1)
        [ -n "$BIGINT_RLIB" ] || BIGINT_RLIB=missing
    fi
    [ "$BIGINT_RLIB" = missing ] && return 2
    printf -- '--extern num_bigint=%s -L %s' "$BIGINT_RLIB" "$(dirname "$BIGINT_RLIB")"
}
RUSTC=${RUSTC:-rustc}

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

is_gap() { case " $KNOWNGAP " in *" $1 "*) return 0;; esac; return 1; }

total=0; ok=0; fail=0; gap=0
skip=0

files=()
if [ -n "$glob" ]; then
    for f in $glob; do [ -f "$f" ] && files+=("$f"); done
else
    for f in "$DIR"/*.py; do [ -f "$f" ] && files+=("$f"); done
fi

for f in "${files[@]}"; do
    bn=$(basename "$f")
    case "$bn" in *_refuse*) continue;; esac
    total=$((total + 1))
    if is_gap "$bn"; then
        gap=$((gap + 1))
        echo "GAP  $bn"
        continue
    fi
    od="$tmp/$bn.dir"; mkdir -p "$od"
    fab=$(readlink -f "$f")
    stdin=/dev/null
    [ -f "${f%.py}.py.stdin" ] && stdin="${f%.py}.py.stdin"
    stdin_abs=$(readlink -f "$stdin")
    native_out=$(cd "$od" && timeout "$TMO" python3 "$fab" <"$stdin_abs" 2>"$od/native.err")
    if ! timeout "$TMO" "$CLI" "$f" - --target rs > "$od/prog.rs" 2>"$od/render.err"; then
        echo "FAIL $bn (render: $(head -c 160 "$od/render.err" | tr '\n' ' '))"
        fail=$((fail + 1)); continue
    fi
    if [ ! -s "$od/prog.rs" ]; then
        echo "FAIL $bn (empty Rust output)"
        fail=$((fail + 1)); continue
    fi
    bf=$(bigint_flags "$od/prog.rs"); bf_rc=$?
    if [ "$bf_rc" = 2 ]; then
        echo "FAIL $bn (needs num_bigint but no rlib found under target/*/deps)"
        fail=$((fail + 1)); continue
    fi
    # --cap-lints allow: the bigint path renders huge decimal literals as
    # const-folded i64 chains (`0 * 10 + 1i64 ...`), which rustc rejects at
    # COMPILE time as arithmetic_overflow (a deny-by-default lint) even though
    # the runtime value comes from the BigInt arm. The chain is dead arithmetic
    # on the exact path, so the lint is irrelevant to the program's semantics.
    if ! (cd "$od" && timeout "$TMO" rustup run 1.90 rustc -O --cap-lints allow $bf -o progbin prog.rs 2>"$od/cc.err"); then
        echo "FAIL $bn (rustc: $(grep -m1 -E '^error' "$od/cc.err" | head -c 200))"
        fail=$((fail + 1)); continue
    fi
    got=$(cd "$od" && timeout "$TMO" ./progbin <"$stdin_abs" 2>"$od/run.err")
    if [ "$got" = "$native_out" ]; then
        ok=$((ok + 1))
    else
        echo "FAIL $bn (stdout: got [$(printf '%s' "$got" | head -c 120 | tr '\n' '|')] want [$(printf '%s' "$native_out" | head -c 120 | tr '\n' '|')])"
        fail=$((fail + 1))
    fi
done

echo "py-rust-gate: $ok/$total match, $fail FAIL, $gap known-gap, $skip skip"
[ "$fail" -eq 0 ]
