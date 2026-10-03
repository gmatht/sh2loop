#!/bin/bash
# harness/pg-dbg.sh — reproduce the ./fail perl leg for one example, with
# full artefacts kept so the diff is inspectable.
#
# Mirrors `fail`::run_one_test exactly: same CLI, same env, same argv0,
# same `do $ARGV[0]` invocation, same byte-for-byte + exit-code comparison.
#
# Usage: harness/pg-dbg.sh <example.sh> [--keep] [more examples...]
#   --keep   leave the work dir behind (default: kept under tmp_run/pg-dbg/)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
WORK="$ROOT/tmp_run/pg-dbg"
TIMEOUT=20
CAP="perl $ROOT/harness/cap-capture.pl 1048576"

mkdir -p "$WORK"
export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

name=$(basename "$1" .sh)
ex="$ROOT/sh2perl/examples/$name.sh"
[ -f "$ex" ] || { echo "no such example: $ex" >&2; exit 2; }

d="$WORK/$name"
rm -rf "$d"; mkdir -p "$d"
cp "$ex" "$d/$name.sh"
cd "$d" || exit 2

# ── generate ────────────────────────────────────────────────────────
if ! timeout "$TIMEOUT" "$CLI" --target pl "$name.sh" > "$d/out.pl" 2> "$d/gen.err"; then
	echo "### $name: GENERATION FAILED"; sed -n '1,15p' "$d/gen.err"; exit 1
fi

if grep -qE "system\('bash', *'[^']*'\)" "$d/out.pl"; then
	echo "### $name: PARSER FALLBACK (bash wrapper)"; exit 1
fi

# ── generated Perl ──────────────────────────────────────────────────
perl_out=$("$ROOT/harness/kill-session.sh" timeout "$TIMEOUT" \
	perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' \
	"$name.sh" "$d/out.pl" 2> "$d/perl.err" | $CAP perl)
perl_exit=$?

# ── bash oracle ─────────────────────────────────────────────────────
bash_out=$("$ROOT/harness/kill-session.sh" timeout "$TIMEOUT" \
	bash "$name.sh" 2> "$d/bash.err" | $CAP perl)
bash_exit=$?

printf '%s' "$perl_out" > "$d/perl.out"
printf '%s' "$bash_out" > "$d/bash.out"

echo "### $name"
echo "    exit:  bash=$bash_exit  perl=$perl_exit"
if [ "$perl_exit" = "$bash_exit" ] && cmp -s "$d/perl.out" "$d/bash.out"; then
	echo "    PASS"
	exit 0
fi
echo "    FAIL  (< expected, > actual)"
diff <(cat "$d/bash.out") <(cat "$d/perl.out") | head -30
[ -s "$d/perl.err" ] && { echo "  --- perl stderr (first 10) ---"; sed -n '1,10p' "$d/perl.err"; }
exit 1