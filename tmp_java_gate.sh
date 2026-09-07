#!/bin/bash
# Reproduce the java backend gate loop (setup_backends.sh --backend-gate java)
#
# Equivalence verdict (bash-faithful): the translated program passes only
# when its stdout matches bash's byte-for-byte AND its exit status equals
# bash's. Both run in the SAME directory (prog.sh / Sh2Program.class,
# both invoked relatively) so `pwd`, `dirname $0` and directory globs see
# one environment; capture files are pre-created so each run's stdout
# redirection does not change the directory listing mid-gate.
#
# Render quality is still enforced: empty output or TODO(unsupported)/
# sh2.* markers count as render failures.
SUB=/home/llm/sh2loop/sh2perl
WT=/home/llm/sh2loop/sh2perl/backends/java
# private copy: other workers rebuild the shared core mid-gate, which
# shows up as spurious emit-empty skips — pin one snapshot per run
CORE="/tmp/java_core_otranspilerl.$$"
cp "$ROOT/otranspilerl/target/debug/otranspilerl-cli" "$CORE"
trap 'rm -f "$CORE"' EXIT
BIN="$WT/target/debug/shir_render"
corpus=$(ls "$SUB"/examples/*.sh /home/llm/sh2loop/frontends/*/testdata/*.sh 2>/dev/null)
pass=0; skip=0; fail=0; stub=0; fails=""; outdir=/tmp/javagate_$$
mkdir -p "$outdir"
i=0
for f in $corpus; do
  i=$((i+1))
  shir=$("$CORE" --target shir "$f" 2>/dev/null)
  if [ -z "$shir" ]; then skip=$((skip+1)); continue; fi
  if ! bash -n "$f" 2>/dev/null; then skip=$((skip+1)); continue; fi
  g_out=$(printf '%s' "$shir" | "$BIN" --target java - 2>/dev/null)
  if [ -z "$g_out" ]; then fail=$((fail+1)); fails="$f(render-empty) $fails"; continue; fi
  s=$(printf '%s' "$g_out" | grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_]' || true)
  if [ "$s" -gt 0 ]; then stub=$((stub+1)); fail=$((fail+1)); fails="$f(stub) $fails"; continue; fi
  bn=$(basename "$f")
  d="$outdir/$i"
  mkdir -p "$d"
  printf '%s' "$g_out" > "$d/Sh2Program.java"
  cp "$f" "$d/prog.sh"
  if ! (cd "$d" && javac Sh2Program.java 2>javac.err); then
    fail=$((fail+1)); fails="$f(javac) $fails"; continue
  fi
  : > "$d/ref.txt"; : > "$d/out.txt"
  bash_rc=0
  (cd "$d" && timeout 15 bash prog.sh </dev/null > ref.txt 2>/dev/null) || bash_rc=$?
  eq_exit=0
  (cd "$d" && timeout 15 java Sh2Program </dev/null > out.txt 2>/dev/null) || eq_exit=$?
  if [ "$eq_exit" != 124 ] && [ "$bash_rc" != 124 ] \
     && [ "$eq_exit" = "$bash_rc" ] \
     && diff -q "$d/ref.txt" "$d/out.txt" >/dev/null 2>&1; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); fails="$f(diff:$bash_rc/$eq_exit) $fails"
  fi
done
echo "PASS=$pass SKIP=$skip FAIL=$fail STUB_FILES=$stub"
echo "fails:"; echo "$fails" | tr ' ' '\n' | grep -v '^$' | sort
