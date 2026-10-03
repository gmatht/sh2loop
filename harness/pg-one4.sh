#!/bin/bash
# Reproduce ONE perl-generator failure exactly the way ./fail does.
# usage: pg-one4.sh <example.sh>   (example name, no .sh needed)
root=/home/llm/sh2loop
ot="$root/otranspilerl/target/debug/otranspilerl-cli"
ex="$1"; [[ $ex == *.sh ]] || ex="$ex.sh"
src="$root/sh2perl/examples/$ex"
tmp=$(mktemp -d /tmp/pgone.XXXXXX)

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

"$ot" --target pl "$src" 2>/dev/null > "$tmp/test.pl"
echo "=== exit(gen)=$? bytes=$(wc -c < "$tmp/test.pl")"

# bash side
"$root/harness/kill-session.sh" timeout 20 bash "$src" > "$tmp/bash.out" 2>"$tmp/bash.err"; bx=$?
# perl side
"$root/harness/kill-session.sh" timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$src" "$tmp/test.pl" > "$tmp/perl.out" 2>"$tmp/perl.err"; px=$?

echo "=== exit bash=$bx perl=$px"
if cmp -s "$tmp/bash.out" "$tmp/perl.out"; then echo "=== STDOUT MATCH"; else
  echo "=== STDOUT MISMATCH"
  diff <(cat -A "$tmp/bash.out") <(cat -A "$tmp/perl.out") | head -40
fi
echo "=== perl stderr:"; head -5 "$tmp/perl.err"
echo "=== workdir $tmp"
