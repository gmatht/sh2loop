#!/bin/bash
# pg-one2.sh <example.sh> — reproduce one corpus example for the [perl] generator.
# Mirrors ./fail's run_one_test: otranspilerl-cli --target pl, run under
# perl -M5.010 with argv0 = source path, compare stdout byte-for-byte + exit.
# Leaves the generated .pl and the bash/perl outputs in $WORK for inspection.
set -u
root=/home/llm/sh2loop
ex="$1"
ex=$(readlink -f "$ex")
name=$(basename "$ex")
WORK=${WORK:-/tmp/commandcode-0/-home-llm-sh2loop/2c4cff20-4cb5-410c-8ce6-33a7dd44d4ca/scratchpad/pg-one2}
mkdir -p "$WORK"
rm -rf "$WORK/$name"; mkdir -p "$WORK/$name"
d="$WORK/$name"

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.lib"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

"$root/otranspilerl/target/debug/otranspilerl-cli" --target pl "$ex" > "$d/gen.pl" 2>"$d/gen.err"
echo "gen exit=$? bytes=$(wc -c < "$d/gen.pl")"

# bash reference
( cd "$d" && timeout 20 bash "$ex" >bash.out 2>bash.err; echo $? > bash.exit )
# perl
( cd "$d" && timeout 20 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$ex" "$d/gen.pl" >perl.out 2>perl.err; echo $? > perl.exit )

be=$(cat "$d/bash.exit"); pe=$(cat "$d/perl.exit")
if cmp -s "$d/bash.out" "$d/perl.out"; then so=OK; else so=MISMATCH; fi
echo "$name: stdout=$so exit(be=$be pe=$pe)"
if [ "$so" = MISMATCH ]; then
  echo "--- first diff (bash | perl) ---"
  diff <(cat -A "$d/bash.out") <(cat -A "$d/perl.out") | head -30
  echo "--- perl.err (tail) ---"; tail -5 "$d/perl.err"
fi
