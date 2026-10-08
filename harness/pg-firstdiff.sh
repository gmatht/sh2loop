#!/usr/bin/env bash
# pg-firstdiff.sh — for each example, reproduce the generator diff and print
# the FIRST diverging line plus a short signature, so failures can be grouped
# by root cause instead of by filename.
#
#   harness/pg-firstdiff.sh [-j N] [example.sh ...]
#
# Reads the example list from stdin when none are given on the command line.
set -u
root="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"

jobs=8
while [ $# -gt 0 ]; do
  case "$1" in
    -j) jobs=${2:-8}; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

one() {
  local name=$1
  local ex="$root/sh2perl/examples/$name"
  [[ -f $ex ]] || ex="$name"
  [[ -f $ex ]] || { printf '%s\tMISSING\t-\n' "$name"; return; }
  local wd; wd=$(mktemp -d "/tmp/pgf-XXXXXX")
  if ! timeout 20 "$CLI" --target pl "$ex" >"$wd/t.pl" 2>"$wd/g.err"; then
    printf '%s\tGENFAIL\t-\n' "$name"; rm -rf "$wd"; return
  fi
  if perl -ne 'exit 0 if /system\('"'"'bash'"'"',\s*'"'"'[^'"'"']*'"'"'\)/; END { exit 1 }' "$wd/t.pl"; then
    printf '%s\tPARSERFALLBACK\t-\n' "$name"; rm -rf "$wd"; return
  fi
  ( exec -a "$ex" timeout 20 perl "$wd/t.pl" ) >"$wd/p.out" 2>"$wd/p.err"
  local pex=$?
  ( exec -a "$ex" timeout 20 bash "$ex" )      >"$wd/b.out" 2>"$wd/b.err"
  local bex=$?
  if [[ $pex != $bex ]]; then
    printf '%s\tEXITDIFF\tperl=%s bash=%s\n' "$name" "$pex" "$bex"
  elif cmp -s "$wd/p.out" "$wd/b.out"; then
    printf '%s\tGREEN\t-\n' "$name"
  else
    # signature = first differing line, trimmed and collapsed
    local sig
    sig=$(diff "$wd/b.out" "$wd/p.out" 2>/dev/null | sed -n 's/^[<>] //p' | head -2 \
          | tr '\n' '|' | tr -d '\t' | cut -c1-110)
    printf '%s\tOUTDIFF\t%s\n' "$name" "$sig"
  fi
  rm -rf "$wd"
}
export -f one
export CLI root

if [ $# -gt 0 ]; then list=("$@"); else mapfile -t list; fi
printf '%s\n' "${list[@]}" | grep -v '^[[:space:]]*$' \
  | xargs -P "$jobs" -I{} bash -c 'one "$@"' _ {}