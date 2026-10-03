#!/bin/bash
# Generate every failing example once into a work dir and report which
# known-bad GENERATOR shapes appear in each. Lets a fix be sized against
# the whole 46 before any code is written.
#   usage: harness/pg-shapes.sh [names-list]
set -u
ROOT=/home/llm/sh2loop
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
LIST="${1:-$ROOT/.perlgen-fails.lst}"
WORK="$ROOT/tmp_run/pgshapes"
rm -rf "$WORK"; mkdir -p "$WORK"

export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

while read -r n; do
  [ -n "$n" ] || continue
  ex="$ROOT/sh2perl/examples/$n"
  [ -f "$ex" ] || ex="$ex.sh"
  [ -f "$ex" ] || continue
  timeout 60 "$CLI" --target pl "$ex" >"$WORK/$n.pl" 2>"$WORK/$n.gerr" || true
done < "$LIST"

printf '%-50s %s\n' "SHAPE" "CASES"
# (A) a Perl value-block spliced INSIDE a shell-seam q-string: bash gets
#     Perl source as its command text.
command grep -lE "__sh_pipe_(capture|run)\(q?\[?'?[^)]*do \{" "$WORK"/*.pl 2>/dev/null \
  | xargs -r -n1 basename | sed 's/\.pl$//' | tr '\n' ' ' | sed 's/^/A embedded do{ in shell payload: /' ; echo
# (B) a capture whose ENTIRE payload is a Perl do{} value block (routed
#     through the shell seam for no reason).
command grep -lE "__sh_pipe_capture\(q\[do \{" "$WORK"/*.pl 2>/dev/null \
  | xargs -r -n1 basename | sed 's/\.pl$//' | tr '\n' ' ' | sed 's/^/B whole payload is a value block: /' ; echo
# (C) a case pattern compiled into a hash subscript that can be empty.
command grep -lE '\$words\{""|\$words\{' "$WORK"/*.pl 2>/dev/null \
  | xargs -r -n1 basename | sed 's/\.pl$//' | tr '\n' ' ' | sed 's/^/C case pattern hash subscript: /' ; echo
# (D) a heredoc delimiter rename left unstripped in the emitted body.
command grep -lE "_SH2DOC_|_SH2HD|_SH2END" "$WORK"/*.pl 2>/dev/null \
  | xargs -r -n1 basename | sed 's/\.pl$//' | tr '\n' ' ' | sed 's/^/D _SH2 doc delimiter in output: /' ; echo
# (E) sort/sort -u reached as an in-process coreutils-ffi call: its hash
#     input has no order, so the result is unstable vs bash.
command grep -lE "'sort'" "$WORK"/*.pl 2>/dev/null \
  | xargs -r -n1 basename | sed 's/\.pl$//' | tr '\n' ' ' | sed 's/^/E in-process sort: /' ; echo
echo "=== generated: $WORK ($(ls "$WORK"/*.pl 2>/dev/null | wc -l) files)"