#!/usr/bin/env bash
# Enumerate every DUPLICATE top-level declaration in the generated Perl for
# the whole corpus, and classify the exact line shapes. This decides whether a
# single dedup post-pass can cover them all or whether some are scope-sensitive
# (a `my` inside a sub or block is LEGAL to repeat and must NOT be collapsed).
#
#   harness/pg-dupe-decls.sh [fail-list | all]
set -u
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cli="$root/otranspilerl/target/debug/otranspilerl-cli"
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

list=${1:-"$root/harness/pg-fail-list.txt"}
scan() {
  local ex=$1
  timeout 25 "$cli" --target pl "$ex" 2>/dev/null
}

if [[ $list == all ]]; then
  while read -r ex; do
    [[ -f $ex ]] || continue
    scan "$ex" | LC_ALL=C awk -v n="$(basename "$ex")" '
      # Track brace depth so we only collapse duplicates at FILE scope; a
      # `my` inside a sub/block may legitimately repeat.
      { line=$0
        d=0
        for(i=1;i<=length(line);i++){c=substr(line,i,1); if(c=="{")d++; else if(c=="}")d--}
        if (match(line, /^my [%@$][A-Za-z_][A-Za-z0-9_]*;$/)) {
          if (d==0) { key=substr(line,4, length(line)-4); seen[key]++; if (seen[key]==2) dup[key]=1 }
        }
      }
      END { for (k in dup) printf "%s\t%s\n", n, k }'
  done < <(ls "$root/sh2perl/examples"/*.sh)
else
  while read -r name; do
    [[ -n $name ]] || continue
    ex="$root/sh2perl/examples/$name"; [[ -f $ex ]] || continue
    scan "$ex" | LC_ALL=C awk -v n="$name" '
      { line=$0; d=0
        for(i=1;i<=length(line);i++){c=substr(line,i,1); if(c=="{")d++; else if(c=="}")d--}
        if (match(line, /^my [%@$][A-Za-z_][A-Za-z0-9_]*;$/)) {
          if (d==0) { key=substr(line,4, length(line)-4); seen[key]++; if (seen[key]==2) dup[key]=1 }
        }
      }
      END { for (k in dup) printf "%s\t%s\n", n, k }'
  done <"$list"
fi
