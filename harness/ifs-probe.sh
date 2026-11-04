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
# FIXED 2026-11-04: this was an xfail.  Measured rule (see the slice
# battery below): the `[@]` face is space-joined ONLY in the WHOLE
# expansion; every SLICE joins on IFS[0] with a space fallback on an
# empty IFS.  The renderer used ' ' for the whole and the slice alike.
emit 21_at_sl_colon      'a=(x y z); IFS=":"; v="${a[@]:1:2}"; printf "[%s]\n" "$v"'
# FIXED 2026-11-02: negative slice length was accepted by both C arms and
# clamped (`cnt+len`), where bash errors. The arms now test `len < 0`
# AFTER the offset guard and exit 1 with bash's own message; the guard
# order is modelled as c31 in `c_str_helpers`/`c_join_ifs` (an offset
# past the end still yields the empty VALUE, not the error).
emit 22_neglen           'a=(a b c d); v="${a[@]:1:-2}"; printf "[%s]\n" "$v"'
# the GUARD ORDER companion: offset out of range beats len<0 (rc 0, "")
emit 23_neglen_off_range 'a=(a b c d); v="${a[@]:9:-2}"; printf "[%s]\n" "$v"'
# an empty array never errors at cnt=0
emit 24_neglen_empty     'a=(); v="${a[@]:0:-1}"; printf "[%s]\n" "$v"'
# scalar `${s:1:-2}` counts back from the STRING end (e = n+len)
emit 25_scalar_neglen    's=abcdef; v="${s:1:-2}"; printf "[%s]\n" "$v"'
# scalar: adjusted end before the offset -> bash errors
emit 26_scalar_neglen_err 's=abcdef; v="${s:3:-5}"; printf "[%s]\n" "$v"'
# ------------------------------------------------- the POSITIONAL faces
# bash (MEASURED 2026-11-03): `$*` joins on IFS[0] — `IFS=:` → p:q:r,
# `IFS=""` → pqr — while `"$@"` ALWAYS joins with a space, whatever IFS
# holds.  The emitted `_sh_argv_join(d, sep)` takes the joiner from the
# call site (`*` → IFS[0], `@` → ' '); before the fix every site passed
# a hard-coded space, so `$*` was silently wrong under any non-default
# IFS (colon / empty / newline).
emit 27_pos_star_colon     'IFS=":"; set -- p q r; printf "[%s]\n" "$*"'
emit 28_pos_star_empty     'IFS=""; set -- p q r; printf "[%s]\n" "$*"'
emit 29_pos_star_assign    'IFS=":"; set -- p q r; v="$*"; printf "[%s]\n" "$v"'
emit 30_pos_at_assign      'IFS=":"; set -- p q r; v="$@"; printf "[%s]\n" "$v"'
# xfail: `unset IFS` — bash REVERTS to the startup IFS (space, so
# `p q r`) while the renderer's unset arm clears the fixed buffer
# (`IFS[0]='\0'`) and `$*` then joins with nothing (`pqr`).  A
# pre-existing unset-arm gap, NOT a join bug — pinned here so it cannot
# drift silently; it goes green when the unset arm restores the startup
# IFS instead of emptying it.
emit 31_xfail_pos_star_unset 'IFS=":"; set -- p q r; unset IFS; printf "[%s]\n" "$*"'
# ------------------------------------------------ the SLICE faces
# bash (MEASURED 2026-11-04): a SLICE joins on IFS[0] for BOTH faces,
# with a SPACE fallback when IFS is empty for `@` (and NOTHING for `*`):
#   IFS=:   ${*:2:2}=q:r   ${@:2:2}=q:r
#   IFS=""  ${*:2:2}=qr    ${@:2:2}=q r
# The whole-expansion forms differ (`$@` is always space-joined), so the
# `@`-slice is NOT the `$@` rule.  Before the fix `_sh_argv_slice` hard-
# coded ' ' and both slice faces ignored IFS entirely.
emit 32_pos_star_slice_colon 'IFS=":"; set -- p q r s; v="${*:2:2}"; printf "[%s]\n" "$v"'
emit 33_pos_at_slice_colon   'IFS=":"; set -- p q r s; v="${@:2:2}"; printf "[%s]\n" "$v"'
emit 34_pos_star_slice_empty 'IFS=""; set -- p q r s; v="${*:2:2}"; printf "[%s]\n" "$v"'
emit 35_pos_at_slice_empty   'IFS=""; set -- p q r s; v="${@:2:2}"; printf "[%s]\n" "$v"'
emit 36_pos_star_slice_comma 'IFS=","; set -- p q r s; v="${*:2:2}"; printf "[%s]\n" "$v"'
emit 37_pos_slice_open_len   'IFS=":"; set -- p q r s; v="${*:2}"; printf "[%s]\n" "$v"'
# offset 0 includes $0 — which differs by construction (`bash <script>`
# vs the compiled binary's argv[0]), so the case strips the $0 field and
# compares only the selected POSITIONAL half.
emit 38_pos_slice_off_zero   'IFS=":"; set -- p q r s; v="${*:0:2}"; printf "[%s]\n" "${v#*:}"'
emit 39_arr_at_slice_empty   'a=(x y z); IFS=""; v="${a[@]:1:2}"; printf "[%s]\n" "$v"'
emit 40_arr_star_whole_colon 'a=(x y z); IFS=":"; printf "<%s>\n" "${a[*]}" "${a[@]}"'
# ------------------------------------- the SPLIT (field-splitting) faces
# bash (MEASURED 2026-11-04): a run of IFS WHITESPACE is ONE delimiter and
# is stripped at both ends; each IFS NON-whitespace char delimits one
# field (`a::b` has an empty middle field, `:a:` an empty first); an
# EMPTY IFS disables splitting. The pre-fix `_sh_split` hard-coded
# space/tab/newline and never read IFS, so `IFS=:; for w in $v` gave 2
# fields where bash gives 4.
emit 41_split_ifs_colon    'v="a::b: c"; IFS=":"; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
emit 42_split_lead_delim   'v=":a:"; IFS=":"; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
emit 43_split_trail_delim  'v="a:b:"; IFS=":"; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
emit 44_split_only_delim   'v=":"; IFS=":"; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
emit 45_split_ws_run       'v="  a  b  "; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
emit 46_split_ws_nw_mix    'v=" a:: b "; IFS=" :"; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
emit 47_split_ws_around_nw 'v="a , b"; IFS=" ,"; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
emit 48_split_empty_ifs    'v="a::b"; IFS=""; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
# the startup IFS is space+tab+newline (not just a space), so a TAB splits
# by default — the decl had to grow the two chars the old hard-coded
# splitter was silently supplying.
emit 49_split_tabnl_default 'v=$(printf "a\tb\nc"); n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
# join then split round trip: `${a[*]}` on a colon IFS, split back
emit 50_split_join_roundtrip 'a=(x y z); IFS=":"; v="${a[*]}"; n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " count=%s\n" "$n"'
# FIXED 2026-11-04: this was an xfail. An IFS the program never ASSIGNED
# used to read "" through the variable face (the read went to
# `_sh_env("IFS")` = getenv) while the splitter consumed the C buffer — so
# `$IFS` DISPLAYED a different value than the one splitting used. The read
# now takes the buffer, and the buffer holds bash's real startup value.
emit 51_ifs_var_read_startup 'printf "n=%s v=[%s]\n" "${#IFS}" "$IFS"'
emit 51b_ifs_var_read_assigned 'IFS=":"; printf "n=%s v=[%s]\n" "${#IFS}" "$IFS"'
# and the displayed value is the one the SPLIT consumes (coherence)
emit 51c_ifs_read_then_split 'printf "[%s]" "$IFS"; v=$(printf "a\tb"); n=0; for w in $v; do n=$((n+1)); printf "<%s>" "$w"; done; printf " n=%s\n" "$n"'
# xfail: an EMPTY unquoted value is folded to a ONE-word list, so the loop
# runs once (bash: zero words). A lowering defect, not a split one — the
# renderer emits `_i_w < 1` without ever calling _sh_split.
emit 52_xfail_empty_for    'e=""; n=0; for w in $e; do n=$((n+1)); done; printf "count=%s\n" "$n"'
# The half a fix must NOT break: a QUOTED empty word IS one field. The two
# programs currently lower to BYTE-IDENTICAL shIR (the unquoted origin is
# not representable in `StrStyle`), which is why 52 cannot be fixed in the
# renderer — filed as core-requests/c-20261104-unquoted-empty-word.md.
emit 52b_quoted_empty_for  'n=0; for w in ""; do n=$((n+1)); done; printf "count=%s\n" "$n"'
# ------------------------------- the FALLBACK slice (`_sh_arr_slice`)
# An array whose storage the emitter cannot walk takes the join-then-split
# arm. That helper split on a SPACE unconditionally while the join it undoes
# uses IFS[0] for `[*]` — so a non-default IFS made the word COUNT wrong.
# A function-local array is the reliable way to reach the arm.
emit 53_fallback_slice_colon 'f(){ local -a b=(p q r); local IFS=:; local v="${b[*]:1:2}"; printf "[%s]\n" "$v"; }; f'
emit 53b_fallback_slice_default 'f(){ local -a b=(p q r); local v="${b[*]:1:2}"; printf "[%s]\n" "$v"; }; f'
emit 53c_fallback_slice_open 'f(){ local -a b=(p q r s); local IFS=:; local v="${b[*]:2}"; printf "[%s]\n" "$v"; }; f'
# FIXED 2026-11-04: this was an xfail (`54_xfail_dense_int_array`). A
# TYPED array (`declare -ia`) is dense INTEGER storage, but the whole-array
# join handed it to `_sh_join_arr_sep`, which walks it as `char **` — a
# SEGV (ASAN: SEGV in _sh_join_arr_sep, read at 0x1; plain run rc 139).
# The dense arm now converts each element inline (`_sh_ll2s`), because the
# width analysis makes the element type per-array (`long long`/`int`/
# `int32_t`) so a typed helper would need a reinterpreting cast.
emit 54_dense_int_array    'declare -ia a=(1 2 3); v="${a[*]}"; printf "[%s]\n" "$v"'
# the FACES on dense storage (bash MEASURED): `[*]` on IFS[0], an EMPTY
# IFS concatenating, `[@]` on a space whatever IFS says.
emit 54b_dense_star_colon  'declare -ia a=(1 2 3); IFS=":"; v="${a[*]}"; printf "[%s]\n" "$v"'
emit 54c_dense_star_empty  'declare -ia a=(1 2 3); IFS=""; v="${a[*]}"; printf "[%s]\n" "$v"'
emit 54d_dense_at_colon    'declare -ia a=(1 2 3); IFS=":"; v="${a[@]}"; printf "[%s]\n" "$v"'
# the values are the INTEGER renderings, including the extremes
emit 54e_dense_neg_extremes 'declare -ia a=(-1 0 -9223372036854775807); v="${a[*]}"; printf "[%s]\n" "$v"'
# the SLICE on dense storage takes the join-then-split fallback, so this
# also checks that the fallback's separator matches the dense join's
emit 54f_dense_slice_colon 'declare -ia a=(1 2 3); IFS=":"; v="${a[*]:1:2}"; printf "[%s]\n" "$v"'
# FIXED 2026-11-04 (was `55_xfail_dense_sparse`): dense value storage now
# carries a PRESENCE marker (`{id}_set[]`), so a hole is no longer a 0
# element — count, join, keys, slice and element reads all follow bash.
# (the KEYS are checked through a for loop, 55c: bash's `${!a[@]}` word-
# splits inside printf, so it cannot be compared as one %s.)
emit 55_dense_sparse       'declare -ia n; n[0]=7; n[2]=9; printf "%s [%s] [%s]\n" "${#n[@]}" "${n[*]}" "${n[1]}"'
# the four readers that need the marker, one case each
emit 55b_dense_unset       'declare -ia n; n[0]=7; n[2]=9; unset "n[0]"; v="${!n[@]}"; printf "%s [%s] [%s] [%s]\n" "${#n[@]}" "${n[*]}" "$v" "${n[0]}"'
emit 55c_dense_keys_loop   'declare -ia n; n[0]=7; n[2]=9; for k in "${!n[@]}"; do printf "<%s>" "$k"; done; echo'
emit 55d_dense_reset       'declare -ia n; n[0]=7; n[2]=9; n=(); n[4]=1; v="${!n[@]}"; printf "%s [%s] [%s]\n" "${#n[@]}" "${n[*]}" "$v"'
emit 55e_dense_read_zero   'declare -ia a=(0 0 0); printf "%s [%s] [%s]\n" "${#a[@]}" "${a[*]}" "${a[1]}"'
# xfail (CORE, not the renderer): `${!arr[*]}` loses its FACE in the shIR —
# both faces lower to `param("slice", "!arr", "@", "")` (measured), so the
# keys join cannot know it was `[*]` and uses the `[@]` space. bash: `0:2`.
# Filed as core-requests/c-20261104-keys-face.md; the values face
# (`${a[*]}` vs `${a[@]}`) is preserved and already correct.
emit 56_xfail_keys_star_face 'declare -ia n; n[0]=7; n[2]=9; IFS=:; printf "[%s]\n" "${!n[*]}"'
# xfail: pre-existing LOWERING shapes the presence work exposed (both are
# wrong with or without the marker, and neither is a join/count bug).
# (a) `arr+=(x)` on a sparse array re-literalises the whole array, so the
#     hole becomes a real 0 element;
# (the array becomes a growable VEC because of `+=`, and the vec form is
#  excluded from the presence marker (`dense_presence`), so it keeps the
#  documented extent rule — the hole reads as a 0 element.)
emit 57_xfail_dense_append_hole 'declare -ia n; n[0]=7; n[2]=9; n+=(3); printf "%s [%s]\n" "${#n[@]}" "${n[*]}"'
# FIXED 2026-11-04 (was `58_xfail_dense_append`): the append path stored the
# elements but never set their presence bits, so they were invisible to the
# count/join (`2 [1 2]`). It now marks them, and lands them at (last SET
# index)+1 with the extent raised to max(base+n, _len).
emit 58_dense_append 'declare -ia a=(1 2); a+=(3 4); printf "%s [%s]\n" "${#a[@]}" "${a[*]}"'
emit 58b_dense_append_chain 'declare -ia b=(1 2); b+=(3); b+=(4 5); printf "%s [%s]\n" "${#b[@]}" "${b[*]}"'
# bash appends after the last SET element, so an array emptied by `unset`
# appends at index 0 while `_len` is still 1 — measured `1 [6] [0]`
emit 58c_dense_append_after_unset 'declare -ia i=(5); unset "i[0]"; i+=(6); v="${!i[@]}"; printf "%s [%s] [%s]\n" "${#i[@]}" "${i[*]}" "$v"'
# the CAP estimate: an index write past the literal extent plus an append
# needs base+appends slots (the old max(reset+appends, idx) exited 127)
emit 58d_dense_append_cap 'declare -ia d=(1); d[3]=9; d+=(5); v="${!d[@]}"; printf "%s [%s] [%s]\n" "${#d[@]}" "${d[*]}" "$v"'
# xfail: an append whose elements are ARITHMETIC/expanded words falls back
# to a `bash -c` emission that is itself malformed (rc 2, "syntax error
# near unexpected token `)'"). Pre-existing and independent of the marker
# — the same fallback arm serves string arrays.
emit 58e_xfail_dense_append_arith 'declare -ia e=(1 2); x=9; e+=($x $((x+1))); printf "%s [%s]\n" "${#e[@]}" "${e[*]}"'
# (c) an element write with an ARITHMETIC subscript (`n[$((i*2))]=$i`)
#     routes the array to assoc storage, so the decl never emits `n_k` —
#     the C does not COMPILE. A BARE `$i` subscript works (59b), so this is
#     the `$(( ))` subscript's key classification, not dense storage's.
emit 59_xfail_dense_arithkey 'declare -ia n; i=1; n[$((i*2))]=5; n[0]=7; printf "%s [%s]\n" "${#n[@]}" "${n[*]}"'
emit 59b_dense_dynkey    'declare -ia n; i=1; n[$i]=5; n[3]=6; printf "%s [%s]\n" "${#n[@]}" "${n[*]}"'

for f in "$D"/cases/*.sh; do
  b=$(basename "$f" .sh)
  w="$D/build/$b"; mkdir -p "$w"
  bash -n "$f" 2>/dev/null || { echo "SKIP $b (bash -n)"; continue; }
  shir=$("$CORE" "$f" --source-lang sh --target shir --raw 2>"$w/sherr") || { echo "FAIL $b (shir rc=$?)"; head -3 "$w/sherr" | sed 's/^/    /'; fail=$((fail+1)); continue; }
  gen=$("$CORE" - --target c <<<"$shir" 2>"$w/rerr") || { echo "FAIL $b (render)"; fail=$((fail+1)); continue; }
  printf '%s' "$gen" > "$w/p.c"
  if ! $CC $UU_INC "$w/p.c" $CLIBS $UU_LIBS -o "$w/bin" 2>"$w/ccerr"; then
    # an `*xfail*` case that does not even COMPILE is still a known
    # failure, not a regression: several of the pinned gaps are "the
    # renderer names storage it never declared" (the C never compiles),
    # and counting those as FAIL made the battery red for a documented
    # gap. Only a NON-xfail cc failure is a failure.
    if [[ "$b" == *xfail* ]]; then xfail=$((xfail+1)); echo "XFAIL $b (cc)";
    else fail=$((fail+1)); echo "FAIL $b (cc)"; fi
    continue
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
