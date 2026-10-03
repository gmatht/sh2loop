#!/usr/bin/env bash
# Classify the CURRENT perl-generator failure list by DIFF SIGNATURE so
# codegen work can be batched per class instead of per file.
# Usage: harness/pg-classify-now.sh <fails.lst> [jobs]
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lst=$1
jobs=${2:-6}
out=$(mktemp -d "${TMPDIR:-/tmp}/pgclass.XXXXXX")

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"

run_one() {
  local n=$1 ex_root=$2 d=$3
  local ex="$ex_root/$n"
  local CLI="$4"
  [ -f "$ex" ] || { echo "$n	NOFILE" >"$d/$n.sig"; return; }
  if ! bash -n "$ex" 2>/dev/null; then echo "$n	BASHPARSE" >"$d/$n.sig"; return; fi
  if ! "$CLI" --target pl "$ex" >"$d/$n.pl" 2>"$d/$n.err"; then
    echo "$n	GENERR" >"$d/$n.sig"; return; fi
  [ -s "$d/$n.pl" ] || { echo "$n	GENEMPTY" >"$d/$n.sig"; return; }
  if grep -qE "system\('bash',\s*'[^']*'\)" "$d/$n.pl"; then
    echo "$n	BASHWRAP" >"$d/$n.sig"; return; fi
  local w="$d/$n.work"; mkdir -p "$w"
  ( cd "$w" && timeout 20 bash "$ex" ) >"$d/$n.bout" 2>/dev/null; local brc=$?
  ( cd "$w" && timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$ex" "$d/$n.pl" ) >"$d/$n.pout" 2>/dev/null; local prc=$?
  local sig
  if cmp -s "$d/$n.bout" "$d/$n.pout" && [ "$brc" = "$prc" ]; then
    sig="PASS"; echo "$n	PASS" >"$d/$n.sig"; rm -rf "$w"; return; fi
  # class: which stream differs, and a normalized shape of the first diff
  local stream
  if cmp -s "$d/$n.bout" "$d/$n.pout"; then stream="exit($brc/$prc)"; else stream="stdout"; fi
  # first differing line pair, whitespace-normalized
  local shape
  shape=$(diff <(cat -A "$d/$n.bout" 2>/dev/null) <(cat -A "$d/$n.pout" 2>/dev/null) 2>/dev/null \
          | awk '/^</{sub(/^< /,"");print; exit}')
  printf '%s\t%s\t%s\n' "$n" "$stream" "$(printf '%s' "$shape" | head -c 160)" >"$d/$n.sig"
}

# NOTE: the worker must be a real script file. `export -f` does NOT survive
# into `bash -c` here (workers are launched from sh, and neither BASH_ENV nor
# an exported FUNCS table is inherited), so an in-function xargs dispatch
# silently produces ZERO output while the whole run still exits 0.
cat >"$out/worker.sh" <<'WEOF'
#!/usr/bin/env bash
set -uo pipefail
WEOF
sed -n '/^run_one() {/,/^}$/p' "$0" >>"$out/worker.sh"
printf 'run_one "$1" "$2" "$3" "$4"\n' >>"$out/worker.sh"
chmod +x "$out/worker.sh"

xargs -a "$lst" -d '\n' -P "$jobs" -I{} "$out/worker.sh" {} "$root/sh2perl/examples" "$out" "$CLI"

echo "--- class counts (stream) ---"
awk -F'\t' '{print $2}' "$out"/*.sig | sort | uniq -c | sort -rn
echo "--- per-file signature ---"
for f in "$out"/*.sig; do cat "$f"; done | sort -t'	' -k2,2
echo "SCRATCH: $out"
