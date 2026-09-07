#!/usr/bin/env bash
# c backend triage: per-file failure classification (stubs / compile / run / mismatch)
# usage: harness/c_triage.sh [corpus-glob...]
set -u
SUB=/home/llm/sh2loop/sh2perl
WT=/home/llm/sh2loop/sh2perl/backends/c
CORE_BIN="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
C_BIN="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
CORPUS=${*:-$(ls "$SUB"/examples/*.sh /home/llm/sh2loop/frontends/*/testdata/*.sh 2>/dev/null)}
mkdir -p /tmp/ctr
rm -f /tmp/ctr/*.txt
pass=0; stub=0; comp=0; segv=0; mismatch=0; skip=0; other=0
for f in $CORPUS; do
  b=$(basename "$f")
  shir=$("$CORE_BIN" "$f" --source-lang sh --target shir --raw 2>/dev/null) || { skip=$((skip+1)); echo "SKIP shir $b" >> /tmp/ctr/skip.txt; continue; }
  [ -z "$shir" ] && { skip=$((skip+1)); echo "SKIP empty $b" >> /tmp/ctr/skip.txt; continue; }
  bash -n "$f" 2>/dev/null || { skip=$((skip+1)); echo "SKIP bashn $b" >> /tmp/ctr/skip.txt; continue; }
  g_out=$(printf '%s' "$shir" | "$C_BIN" - --target c 2>/dev/null) || { other=$((other+1)); echo "RENDER-ERR $b" >> /tmp/ctr/other.txt; continue; }
  s=$(printf '%s' "$g_out" | grep -cE "TODO\(unsupported\)|sh2[A-Za-z_]" || true)
  if [ "$s" -gt 0 ]; then
    stub=$((stub+1))
    # categorize the stub names
    names=$(printf '%s' "$g_out" | grep -oE "sh2[A-Za-z_]+" | sort -u | tr '\n' ' ')
    todos=$(printf '%s' "$g_out" | grep -oE "TODO\(unsupported\)[^)]*" | sort -u | tr '\n' ' ')
    echo "$b :: $names :: $todos" >> /tmp/ctr/stubs.txt
    continue
  fi
  printf '%s' "$g_out" > /tmp/ctr/t.c
  if ! cc /tmp/ctr/t.c -o /tmp/ctr/t 2>/tmp/ctr/cc.err; then
    comp=$((comp+1)); echo "$b :: $(head -c 300 /tmp/ctr/cc.err | tr '\n' ' ')" >> /tmp/ctr/compile.txt; continue
  fi
  timeout 10 /tmp/ctr/t > /tmp/ctr/out 2>/dev/null; rc=$?
  if [ $rc -eq 139 ] || [ $rc -eq 132 ]; then segv=$((segv+1)); echo "$b" >> /tmp/ctr/segv.txt; continue; fi
  if [ $rc -ne 0 ]; then mismatch=$((mismatch+1)); echo "$b :: rc=$rc" >> /tmp/ctr/mismatch.txt; continue; fi
  timeout 10 bash "$f" > /tmp/ctr/ref 2>/dev/null
  if ! diff -q /tmp/ctr/out /tmp/ctr/ref >/dev/null 2>&1; then
    mismatch=$((mismatch+1))
    echo "$b" >> /tmp/ctr/mismatch.txt
    diff /tmp/ctr/out /tmp/ctr/ref | head -20 >> /tmp/ctr/mismatch-detail.txt 2>/dev/null
  else
    pass=$((pass+1)); echo "$b" >> /tmp/ctr/pass.txt
  fi
done
echo "== pass=$pass stub=$stub compile=$comp segv=$segv mismatch=$mismatch skip=$skip other=$other (total=$((pass+stub+comp+segv+mismatch+skip+other)))"
