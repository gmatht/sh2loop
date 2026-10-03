#!/usr/bin/env bash
# triage-dbg.sh <frontend> <example.ext> <backend> — show native / estree-ref /
# backend output side by side for one pair, so a FAIL-BACKEND "differs" verdict
# can be attributed to a specific line instead of re-derived by hand.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FE="$1"; EX="$2"; BE="$3"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
RUNNER="$ROOT/harness/estree-runner.mjs"
FEDIR="$ROOT/sh2perl/frontends/$FE"
SRC="$FEDIR/testdata/$EX"
TMP=$(mktemp -d /tmp/triagedbg.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

( cd "$FEDIR" && ./"$FE" --shir "testdata/$EX" --raw ) > "$TMP/a1.json" 2>"$TMP/emit.err" || { echo "EMIT FAILED"; cat "$TMP/emit.err"; exit 1; }
( cd "$TMP" && timeout 20 python3 "$SRC" ) > "$TMP/native" 2>/dev/null
"$CLI" - --target estree < "$TMP/a1.json" > "$TMP/estree.json" 2>"$TMP/render.err" || {
  echo "== ESTREE RENDER FAILED"; cat "$TMP/render.err"; exit 1; }
node "$RUNNER" "$TMP/estree.json" --source "$SRC" > "$TMP/estree" 2>"$TMP/estree.err" || true

BIN="$CLI"; FLAG="$BE"
"$CLI" - --target "$FLAG" < "$TMP/a1.json" > "$TMP/out.$BE" 2>"$TMP/be.err" || {
  echo "== $BE RENDER FAILED"; cat "$TMP/be.err"; exit 1; }
case "$BE" in
  sh)  ( cd "$TMP" && timeout 30 bash out.sh ) > "$TMP/be" 2>/dev/null ;;
  rust) ( cd "$TMP" && cp out.rs main.rs && timeout 60 rustc main.rs -o main 2>/dev/null && timeout 30 ./main ) > "$TMP/be" 2>/dev/null ;;
esac

for w in native estree be; do
  echo "───── $w ─────"
  cat "$TMP/$w" 2>/dev/null
done
echo "───── diff native vs $BE ─────"
diff -u "$TMP/native" "$TMP/be" || true
echo "───── diff estree vs $BE ─────"
diff -u "$TMP/estree" "$TMP/be" || true
echo "───── rendered $BE: ${TMP}/out.$BE ─────"
