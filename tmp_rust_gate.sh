#!/bin/bash
# Reproduce the rust backend gate loop (setup_backends.sh --backend-gate rust)
#
# Equivalence verdict (bash-faithful): the translated program passes only
# when its stdout matches bash's byte-for-byte AND its exit status equals
# bash's. Both run in the SAME directory with the SAME argv0 shape
# (prog.sh vs prog.bin, both relative) so `dirname $0`, `pwd` and
# directory globs see the same environment; bash runs FIRST so files it
# creates by redirection exist for both runs (glob-listing scripts see
# one consistent world).
#
# Render quality is still enforced: empty output, TODO(unsupported)
# markers or sh2.* stubs count as render failures.
# argv0: $0 is part of a script's observable behavior, so both runs get
# the SAME argv0 ("prog.sh") — the binary via `exec -a`.
SUB=/home/llm/sh2loop/sh2perl
WT=/home/llm/sh2loop/sh2perl/backends/rust
CORE=/home/llm/sh2loop/otranspilerl/target/debug/otranspilerl-cli
BIN="$WT/target/debug/shir_render"
corpus=$(ls "$SUB"/examples/*.sh /home/llm/sh2loop/frontends/*/testdata/*.sh 2>/dev/null)
pass=0; skip=0; fail=0; stub=0; fails=""; outdir=/tmp/rustgate_$$
mkdir -p "$outdir"
i=0
for f in $corpus; do
  i=$((i+1))
  shir=$("$CORE" --target shir "$f" 2>/dev/null)
  if [ -z "$shir" ]; then skip=$((skip+1)); continue; fi
  if ! bash -n "$f" 2>/dev/null; then skip=$((skip+1)); continue; fi
  g_out=$(printf '%s' "$shir" | "$BIN" --target rust - 2>/dev/null)
  if [ -z "$g_out" ]; then fail=$((fail+1)); fails="$f $fails"; continue; fi
  s=$(printf '%s' "$g_out" | grep -cE "TODO\(unsupported\)|sh2[A-Za-z_]" || true)
  if [ "$s" -gt 0 ]; then stub=$((stub+1)); fail=$((fail+1)); fails="$f $fails"; continue; fi
  bn=$(basename "$f")
  d="$outdir/$i"
  mkdir -p "$d"
  printf '%s' "$g_out" > "$d/prog.rs"
  cp "$f" "$d/prog.sh"
  if ! rustc "$d/prog.rs" -o "$d/prog.bin" 2>/dev/null; then
    fail=$((fail+1)); fails="$f $fails"; continue
  fi
  # Pre-create both capture files so each run's stdout redirection does
  # not change the directory listing mid-gate: scripts that glob their
  # own directory must see one consistent world in both runs.
  : > "$d/ref.txt"; : > "$d/out.txt"
  bash_rc=0
  (cd "$d" && timeout 15 bash prog.sh > ref.txt 2>/dev/null) || bash_rc=$?
  eq_exit=0
  (cd "$d" && timeout 15 bash -c 'exec -a prog.sh ./prog.bin' > out.txt 2>/dev/null) || eq_exit=$?
  if [ "$eq_exit" != 124 ] && [ "$bash_rc" != 124 ] \
     && [ "$eq_exit" = "$bash_rc" ] \
     && diff -q "$d/ref.txt" "$d/out.txt" >/dev/null 2>&1; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); fails="$f $fails"
  fi
done
echo "PASS=$pass SKIP=$skip FAIL=$fail STUB_FILES=$stub"
echo "fails:"; echo "$fails" | tr ' ' '\n' | grep -v '^$' | sort
