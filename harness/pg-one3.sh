#!/usr/bin/env bash
# Reproduce one corpus example against the Perl GENERATOR: transpile, run
# the generated Perl, run bash, and diff stdout + exit code byte-for-byte.
#
#   harness/pg-one3.sh <example.sh> [--ir] [--keep]
#
# --ir   also dump the IR the pre-pass sees (PG_DUMP_IR)
# --keep leave the workdir behind and print its path
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ex=${1:-}; shift || true
[[ -n $ex ]] || { echo "usage: pg-one3.sh <example.sh> [--ir] [--keep]" >&2; exit 2; }
dump_ir=0; keep=0
for a in "$@"; do
  case "$a" in
    --ir)   dump_ir=1 ;;
    --keep) keep=1 ;;
  esac
done

name=$(basename "$ex")
[[ -f $ex ]] || ex="$root/sh2perl/examples/$name"
[[ -f $ex ]] || { echo "no such example: $name" >&2; exit 2; }

cli="$root/otranspilerl/target/debug/otranspilerl-cli"
[[ -x $cli ]] || { echo "CLI not built: $cli" >&2; exit 2; }

wd=$(mktemp -d "/tmp/pg1-XXXXXX")
trap '[[ $keep == 1 ]] || rm -rf "$wd"' EXIT

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
[[ $dump_ir == 1 ]] && export PG_DUMP_IR=1

if ! timeout 20 "$cli" --target pl "$ex" >"$wd/test.pl" 2>"$wd/gen.err"; then
  echo "== GENERATE FAILED =="; tail -5 "$wd/gen.err"; exit 1
fi

# Reject the bash-wrapper fallback — but match the GATE's exact pattern
# (fail:175: /system\('bash',\s*'[^']*'\)/), not a loose "system('bash',".
# The generated PRELUDE always contains `system('bash', '-c', $cmd)` inside
# __sh_pipe_run's shell-fallback arm, so the loose pattern flagged every
# pipeline-using example as a parser gap and hid the real stdout diff.
if perl -ne 'exit 0 if /system\('"'"'bash'"'"',\s*'"'"'[^'"'"']*'"'"'\)/; END { exit 1 }' "$wd/test.pl"; then
  echo "== PARSER FALLBACK (bash wrapper) =="; exit 1
fi

if ! perl "$root/check_qx.pl" "$wd/test.pl" >"$wd/qx.out" 2>&1; then
  echo "== check_qx FAIL =="; grep FAIL "$wd/qx.out" | head -5; exit 1
fi

# Same invocation shape as the gate: argv0 is the SOURCE script path.
( exec -a "$ex" timeout 20 perl "$wd/test.pl" ) >"$wd/perl.out" 2>"$wd/perl.err"
pex=$?
( exec -a "$ex" timeout 20 bash "$ex" )      >"$wd/bash.out" 2>"$wd/bash.err"
bex=$?

echo "== $name =="
echo "-- exit: perl=$pex bash=$bex"
if cmp -s "$wd/perl.out" "$wd/bash.out"; then
  echo "-- stdout: IDENTICAL ($(wc -c <"$wd/perl.out") bytes)"
else
  echo "-- stdout: MISMATCH (perl=$(wc -c <"$wd/perl.out") bash=$(wc -c <"$wd/bash.out"))"
  diff -u "$wd/bash.out" "$wd/perl.out" | head -40
fi
if ! cmp -s "$wd/perl.err" "$wd/bash.err"; then
  echo "-- stderr differs:"; diff -u "$wd/bash.err" "$wd/perl.err" | head -10
fi
[[ $keep == 1 ]] && echo "-- workdir: $wd"
[[ $pex == $bex ]] && cmp -s "$wd/perl.out" "$wd/bash.out"
