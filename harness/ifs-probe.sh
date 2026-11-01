#!/usr/bin/env bash
# ifs-probe.sh — the IFS / join-face battery behind `c_join_ifs.rs`
# (C_UB_PROOF.md §28).  For each case: render the script to C, compile,
# run, and diff against bash — so a model claim about a face (`[*]`
# joins on IFS[0], `[@]` on a space, an empty IFS joins with nothing,
# bounds count ELEMENTS) is checked against real bash, not against the
# model.  Cases named *_xfail_* are DOCUMENTED divergences (the `[@]`
# face collapsing to one word, and bash rejecting a negative slice
# length) — they are expected to differ and must never be blessed.
#
#   CORE_BIN=/path/to/otranspilerl-cli  SH2_ROOT=/path/to/workspace
#
# Exit: 0 when every non-xfail case agrees with bash.
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CORE="${CORE_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
CC=cc
CLIBS="-lgmp -lm"
UU_SRC="$ROOT/sh2perl/runtime/uu_run.c"; UU_LIBDIR="$ROOT/sh2perl/runtime/lib"
UU_SO="$UU_LIBDIR/libcoreutils_ffi.so"
UU_LIBS=""; UU_INC=""
if [ -f "$UU_SRC" ] && [ -f "$UU_SO" ]; then
  UU_LIBS="$UU_SRC $UU_SO -lpthread -Wl,-rpath,$UU_LIBDIR"
  UU_INC="-I$ROOT/sh2perl/runtime -I$UU_LIBDIR"
else
  export SH2_UU_FFI=0
fi

export OTRANSPILER_ROOT="$ROOT"
D=$(mktemp -d /tmp/probe_ifs.XXXXXX)
mkdir -p "$D/cases" "$D/build"
pass=0; fail=0; xfail=0; xpass=0

emit() { printf '%s\n' "$2" > "$D/cases/$1.sh"; }

# ---------------------------------------------------------------- faces
emit 01_star_default      'a=(x y z); printf "[%s]\n" "${a[*]}"'
emit 02_star_colon        'a=(x y z); IFS=":"; printf "[%s]\n" "${a[*]}"'
emit 03_star_empty        'a=(x y z); IFS=""; printf "[%s]\n" "${a[*]}"'
emit 04_star_assign_colon 'a=(x y z); IFS=":"; v="${a[*]}"; printf "[%s]\n" "$v"'
emit 05_star_slice_colon  'a=(x y z); IFS=":"; v="${a[*]:1:2}"; printf "[%s]\n" "$v"'
emit 06_star_slice_def    'a=(x y z); v="${a[*]:1:2}"; printf "[%s]\n" "$v"'
# xfail: the `[@]` face in a MULTI-WORD context (printf/args) collapses to
# one string in the C renderer — bash passes one ARG PER ELEMENT
# (C_UB_PROOF.md §28 "Not modelled").
emit 07_xfail_at_multiword 'a=(x y z); printf "[%s]\n" "${a[@]}"'
emit 08_at_slice_default  'a=(x y z); v="${a[@]:1:2}"; printf "[%s]\n" "$v"'
emit 09_holes_star        'a=(a b c); a[5]=z; printf "[%s]\n" "${a[*]}"'
emit 10_holes_slice       'a=(a b c); a[5]=z; v="${a[*]:1:3}"; printf "[%s]\n" "$v"'
emit 11_empty_elem        'a=(a "" c); printf "[%s]\n" "${a[*]}"'
emit 12_ifs_read_first    'a=(x y z); printf "[%s]\n" "${a[*]}"'
emit 13_ifs_declared_late 'a=(x y z); printf "[%s]\n" "${a[*]}"; IFS=":"; printf "[%s]\n" "${a[*]}"'
emit 14_slice_off_big     'a=(x y z); v="${a[*]:7:2}"; printf "[%s]\n" "$v"'
emit 15_slice_len_zero    'a=(x y z); v="${a[*]:1:0}"; printf "[%s]\n" "$v"'
emit 16_keys_star         'declare -A m=([k1]=v1 [k2]=v2); printf "[%s]\n" "${!m[*]}"'
emit 17_argv_star         'set -- p q r; printf "[%s]\n" "$*"'
emit 18_at_forloop        'a=(x y z); for w in "${a[@]}"; do printf "<%s>" "$w"; done; echo'
# xfail: `for w in "${a[*]}"` lowers to `TODO(unsupported): for item
# type` and the whole loop is DROPPED (zero iterations; bash iterates
# once with the join) — a pre-existing backend gap, not a face bug.
emit 19_xfail_star_forloop 'a=(x y z); for w in "${a[*]}"; do printf "<%s>" "$w"; done; echo'
# xfail: [@] collapses to one word in the renderer (documented G4)
emit 20_xfail_at_colon    'a=(x y z); IFS=":"; printf "[%s]\n" "${a[@]}"'
emit 21_xfail_at_sl_colon 'a=(x y z); IFS=":"; v="${a[@]:1:2}"; printf "[%s]\n" "$v"'
# xfail: negative slice length is accepted by the C arms, bash errors
emit 22_xfail_neglen      'a=(a b c d); v="${a[@]:1:-2}"; printf "[%s]\n" "$v"'

for f in "$D"/cases/*.sh; do
  b=$(basename "$f" .sh)
  w="$D/build/$b"; mkdir -p "$w"
  bash -n "$f" 2>/dev/null || { echo "SKIP $b (bash -n)"; continue; }
  shir=$("$CORE" "$f" --source-lang sh --target shir --raw 2>"$w/sherr") || { echo "FAIL $b (shir rc=$?)"; head -3 "$w/sherr" | sed 's/^/    /'; fail=$((fail+1)); continue; }
  gen=$("$CORE" - --target c <<<"$shir" 2>"$w/rerr") || { echo "FAIL $b (render)"; fail=$((fail+1)); continue; }
  printf '%s' "$gen" > "$w/p.c"
  if ! $CC $UU_INC "$w/p.c" $CLIBS $UU_LIBS -o "$w/bin" 2>"$w/ccerr"; then
    echo "FAIL $b (cc)"; fail=$((fail+1)); continue
  fi
  ( cd "$w" && timeout 10 bash "$f" >ref 2>/dev/null ); brc=$?
  ( cd "$w" && timeout 10 "$w/bin" "$f" >out 2>/dev/null ); crc=$?
  if [ "$brc" = "$crc" ] && diff -q "$w/out" "$w/ref" >/dev/null 2>&1; then
    if [[ "$b" == *xfail* ]]; then xpass=$((xpass+1)); echo "XPASS $b (divergence now fixed!)";
    else pass=$((pass+1)); echo "PASS  $b"; fi
  else
    if [[ "$b" == *xfail* ]]; then xfail=$((xfail+1)); echo "XFAIL $b";
    else fail=$((fail+1)); echo "FAIL  $b (rc $brc/$crc)";
      echo "--- ref:"; sed 's/^/    /' "$w/ref";
      echo "--- out:"; sed 's/^/    /' "$w/out";
    fi
  fi
done
echo "== PASS=$pass FAIL=$fail XFAIL=$xfail XPASS=$xpass"
echo "build dir: $D"
[ "$fail" -eq 0 ]
