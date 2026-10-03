#!/usr/bin/env bash
# Cluster the Perl GENERATOR corpus failures by ROOT CAUSE.
#
#   harness/pg-cluster.sh [example.sh ...]
#
# With no args it reads the failing names from harness/pg-fail-list.txt.
#
# The invocation mirrors `fail` EXACTLY (fail:205 / fail:224), because a
# different one produces phantom diffs:
#
#   * `perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f'`
#     runs the generated file in the MAIN scope with @ARGV emptied and $0 set
#     to the SOURCE path. `perl test.pl` instead runs it as a separate script
#     with @ARGV passed through, so an example that reads "$@" or $0 disagrees
#     for reasons that have nothing to do with codegen.
#   * kill-session.sh + setsid + `timeout -k` so a forked writer is killed with
#     its process group rather than leaking (096_head_procsub.sh).
#   * cap-capture.pl on BOTH sides, for the same 1 MiB / no-EPIPE reason the
#     gate has: a cap that truncates with `head` would let a runaway example
#     keep writing, and a *differing* cap on the two sides is a false diff.
#
# The first differing line, normalized, is the group key: two examples with
# the same key are the same bug and get fixed together.
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cli="$root/otranspilerl/target/debug/otranspilerl-cli"
[[ -x $cli ]] || { echo "CLI not built" >&2; exit 2; }

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

TMO=${PG_TIMEOUT:-20}
# cap-capture.pl reads the byte ceiling from its FIRST argument and the label
# from the second; stdin is drained to stdout. The ceiling must be identical on
# both sides or the cap itself manufactures a diff.
CAP_BYTES=${PG_CAP_BYTES:-1048576}
# label is the caller's $1; the byte ceiling is fixed so both sides agree.
cap() { LC_ALL=C perl "$root/harness/cap-capture.pl" "$CAP_BYTES" "${1:-output}"; }

# The gate's own template, so a change to it cannot silently desync us.
PERL_RUN='$0 = shift @ARGV; my $__f = shift @ARGV; do $__f'

one() {
  local name=$1
  local ex="$root/sh2perl/examples/$name"
  [[ -f $ex ]] || { printf '%s\tNOEXAMPLE\t-\n' "$name"; return; }
  local wd; wd=$(mktemp -d "/tmp/pgc-XXXXXX")

  if ! timeout 25 "$cli" --target pl "$ex" >"$wd/test.pl" 2>"$wd/gen.err"; then
    printf '%s\tGEN-FAIL\t%s\n' "$name" "$(head -c 160 "$wd/gen.err" | tr '\n\t' '  ')"
    rm -rf "$wd"; return
  fi

  # The gate's exact bash-wrapper pattern (fail:175).
  if perl -ne 'exit 0 if /system\('"'"'bash'"'"',\s*'"'"'[^'"'"']*'"'"'\)/; END { exit 1 }' "$wd/test.pl"; then
    printf '%s\tBASH-FALLBACK\t-\n' "$name"; rm -rf "$wd"; return
  fi

  # The generated program's own stdout goes to a FILE, and the exit code is
  # read from the runner directly. Piping through cap-capture into a
  # subshell makes PIPESTATUS unreliable and swallowed the output entirely on
  # the first version of this script, which showed up as STDOUT+NO-LINE-DIFF
  # — a verdict that contradicts itself. Run the runner with its stdout
  # already redirected, then drain that file through the cap in a separate
  # step: the cap is still applied on both sides (so a runaway is bounded
  # identically), and the exit code is the runner's own, not a pipeline's.
  "$root/harness/kill-session.sh" timeout "$TMO" \
    perl -M5.010 -e "$PERL_RUN" "$ex" "$wd/test.pl" \
    >"$wd/p.raw" 2>"$wd/perl.err"
  local pex=$?

  "$root/harness/kill-session.sh" timeout "$TMO" bash "$ex" \
    >"$wd/b.raw" 2>"$wd/bash.err"
  local bex=$?

  cap perl <"$wd/p.raw" >"$wd/p.out"
  cap bash <"$wd/b.raw" >"$wd/b.out"

  local verdict sig
  if [[ $pex != $bex ]]; then
    verdict="EXIT(p=$pex b=$bex)"
  elif cmp -s "$wd/p.out" "$wd/b.out"; then
    verdict="PASS"
  else
    verdict="STDOUT"
  fi

  sig=$(LC_ALL=C diff "$wd/b.out" "$wd/p.out" 2>/dev/null | LC_ALL=C awk '
    /^[0-9]/ { next }
    /^</ { if (!b) b=$0 ; next }
    /^>/ { if (!p) p=$0 ; next }
    END {
      gsub(/^[<>] /,"",b); gsub(/^[<>] /,"",p);
      if (b=="" && p=="") print "NO-LINE-DIFF"
      else print substr(b,1,68) " ||| " substr(p,1,68)
    }')
  [[ -z $sig ]] && sig="-"
  printf '%s\t%s\t%s\n' "$name" "$verdict" "$sig"
  rm -rf "$wd"
}

if [[ $# -gt 0 ]]; then
  for n in "$@"; do one "$n"; done
else
  while read -r name; do [[ -n $name ]] && one "$name"; done <"$root/harness/pg-fail-list.txt"
fi
