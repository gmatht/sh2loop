#!/usr/bin/env bash
# repro-pair.sh <frontend> <example> <backend> — reproduce one triage pair:
#   frontend emit → A1 → estree reference (render+run) vs native
#                       → <backend> mirror render (+run) vs native
# usage: harness/repro-pair.sh bat-sh-go t36_redirect_var.bat perl
set -u
ROOT=/home/llm/sh2loop
DEBASHC="$ROOT/sh2perl/target/debug/debashc"
RUNNER="$ROOT/harness/estree-runner.mjs"
FE="$1"; EX="$2"; BE="$3"
FE_DIR="$ROOT/frontends/$FE"
SRC=""
case "$FE" in
  sh2perl) SRC="$ROOT/sh2perl/examples/$EX"; A1=$("$DEBASHC" --shir "$SRC" --raw 2>/dev/null);;
  *)
    case "$FE" in
      c-sh-go) BIN="$FE_DIR/c-sh-go"; EXT=c;;
      cpp-sh-go) BIN="$FE_DIR/cpp-sh-go"; EXT=cc;;
      bat-sh-go) BIN="$FE_DIR/bat-sh-go"; EXT=bat;;
      py-sh-go) BIN="$FE_DIR/py-sh-go"; EXT=py;;
      perl-sh-go) BIN="$FE_DIR/perl-sh-go"; EXT=pl;;
      posix-sh-go) BIN="$FE_DIR/posix-sh-go"; EXT=sh;;
      zsh-sh-go) BIN="$FE_DIR/zsh-sh-go"; EXT=zsh;;
      fish-sh-go) BIN="$FE_DIR/fish-sh-go"; EXT=fish;;
      go-sh) BIN="$FE_DIR/go-sh"; EXT=go;;
      powershell-sh-go) BIN="$FE_DIR/powershell-sh-go"; EXT=ps1;;
      rust-frontend) BIN="$FE_DIR/target/debug/rust-frontend"; EXT=rs;;
      zig-sh-go) BIN="$FE_DIR/zig-sh-go"; EXT=zig;;
    esac
    SRC="$FE_DIR/testdata/$EX"
    A1=$("$BIN" --shir "$SRC" --raw 2>/dev/null)
    ;;
esac
if [ -z "$A1" ]; then echo "EMIT-FAIL: no A1"; exit 1; fi
TMP=$(mktemp -d /tmp/repro.XXXXXX)
printf '%s' "$A1" > "$TMP/a1.json"

# native
case "$FE" in
  sh2perl|posix-sh-go) timeout 20 bash "$SRC" > "$TMP/native" 2>/dev/null;;
  zsh-sh-go) ( cd "$FE_DIR" && timeout 20 zsh "$EX" ) > "$TMP/native" 2>/dev/null;;
  fish-sh-go) ( cd "$FE_DIR" && timeout 20 fish "$EX" ) > "$TMP/native" 2>/dev/null;;
  go-sh) ( cd "$TMP" && grep -q 'func main()' "$SRC" && cp "$SRC" main.go || { printf 'package main\nimport "fmt"\nfunc main() {\n'; cat "$SRC"; printf '}\n'; } > main.go; timeout 20 go run main.go ) > "$TMP/native" 2>/dev/null;;
  *) : > "$TMP/native";;
esac
echo "== native rc=$? out: $(head -c 200 "$TMP/native" | tr '\n' '|')"

# estree reference
if "$DEBASHC" --shir-in-estree "$TMP/a1.json" > "$TMP/e.json" 2>/dev/null; then
  out=$(timeout 30 node "$RUNNER" "$TMP/e.json" --source "$SRC" 2>/dev/null)
  if diff -q <(printf '%s' "$out") "$TMP/native" >/dev/null 2>&1; then
    echo "== estree: MATCHES native"
  else
    echo "== estree: DIFFERS  (ref: $(head -c 200 "$out" | tr '\n' '|'))"
  fi
else
  echo "== estree: RENDER-FAIL"
fi

# backend mirror render
case "$BE" in
  js) FLAG=--shir-in-js;;
  perl) FLAG=--shir-in-perl;;
  sh) FLAG=--shir-in-sh;;
  c) FLAG=--shir-in-c;;
  go) FLAG=--shir-in-go;;
  python) FLAG=--shir-in-python;;
  java) FLAG=--shir-in-java;;
  rust) FLAG=--shir-in-rust;;
  zig) FLAG=--shir-in-zig;;
esac
if ! "$DEBASHC" "$FLAG" "$TMP/a1.json" > "$TMP/rendered" 2>"$TMP/render.err"; then
  echo "== $BE: RENDER-FAIL: $(head -c 200 "$TMP/render.err" | tr '\n' '|')"
  exit 0
fi
echo "== $BE rendered: $(head -c 400 "$TMP/rendered" | tr '\n' '|')"
echo "$TMP"
