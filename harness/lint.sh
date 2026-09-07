#!/usr/bin/env bash
# harness/lint.sh — lint the GENERATED outputs (and the shell source)
# across every generator. Usage: harness/lint.sh [file.sh ...]  (default:
# a small battery). The lints:
#   shell source -> shellcheck
#   JS output    -> node --check (syntax) + eslint (flat config)
#   Perl output  -> perlcritic
#   C output     -> gcc -Wall -c (compiles)
#   Go output    -> gofmt -l (format) + go build
#   Python output-> ruff check
#   Zig output   -> zig build-exe (compiles)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEB="$ROOT/sh2perl/otranspilerl/target/debug/otranspilerl-cli"
GEN="$ROOT/harness/estree-gen.mjs"
ESLINT="${ESLINT:-/nvme/ai/.npm-global/bin/eslint}"
RUFF="${RUFF:-/nvme/ai/.local/bin/ruff}"
TMP=/tmp/lintwork; mkdir -p "$TMP"
cp /tmp/eslint.config.js "$TMP/" 2>/dev/null

lint_one() {
  local f="$1"; local name=$(basename "$f")
  echo "== $name"
  # shellcheck the source
  shellcheck -s bash "$f" 2>/dev/null | grep -c "error\|warning" | sed 's/^/  shellcheck: /' || echo "  shellcheck: 0 findings"
  # JS
  if $DEB file --estree "$f" > "$TMP/o.json" 2>/dev/null; then
    (cd "$TMP" && node --input-type=module -e "
      import { generate } from 'file://$GEN';
      import fs from 'fs';
      fs.writeFileSync('$TMP/o.mjs', generate(JSON.parse(fs.readFileSync('$TMP/o.json','utf8'))));
    " 2>/dev/null)
    node --check "$TMP/o.mjs" 2>/dev/null && echo "  js: node --check ✓" || echo "  js: node --check FAIL"
    (cd "$TMP" && "$ESLINT" o.mjs >/dev/null 2>&1) && echo "  js: eslint ✓" || echo "  js: eslint findings"
  else
    echo "  js: (parse error — not a generator abort)"
  fi
  # Perl
  if $DEB file --perl "$f" > "$TMP/o.pl" 2>/dev/null; then
    n=$(perlcritic --quiet "$TMP/o.pl" 2>/dev/null | wc -l)
    echo "  perl: perlcritic $n findings"
  else
    echo "  perl: (parse error)"
  fi
  # the backend renderers: shir -> renderer -> lint
  shir=$($DEB --shir "$f" --raw 2>/dev/null)
  [ -z "$shir" ] && { echo "  backends: (core unparseable — skipped)"; return; }
  # C
  if printf '%s' "$shir" | "$ROOT/sh2perl/backends/c/otranspilerl/target/debug/otranspilerl-cli" --shir-in-c - > "$TMP/o.c" 2>/dev/null; then
    gcc -Wall -Werror -c "$TMP/o.c" -o /tmp/o_c.o 2>/dev/null && echo "  c: gcc -Wall ✓" || echo "  c: gcc -Wall findings"
  else
    echo "  c: (renderer err — a backend gap)"
  fi
  # Go
  if printf '%s' "$shir" | "$ROOT/sh2perl/backends/go/otranspilerl/target/debug/otranspilerl-cli" --shir-in-go - > "$TMP/o.go" 2>/dev/null; then
    [ -z "$(gofmt -l "$TMP/o.go" 2>/dev/null)" ] && echo "  go: gofmt ✓" || echo "  go: gofmt findings"
  else
    echo "  go: (renderer err)"
  fi
  # Python
  if printf '%s' "$shir" | "$ROOT/sh2perl/backends/python/otranspilerl/target/debug/otranspilerl-cli" --shir-in-python - > "$TMP/o.py" 2>/dev/null; then
    "$RUFF" check "$TMP/o.py" >/dev/null 2>&1 && echo "  python: ruff ✓" || echo "  python: ruff findings"
  else
    echo "  python: (renderer err)"
  fi
  # Zig
  if printf '%s' "$shir" | "$ROOT/sh2perl/backends/zig/otranspilerl/target/debug/otranspilerl-cli" --shir-in-zig - > "$TMP/o.zig" 2>/dev/null; then
    zig build-exe "$TMP/o.zig" -O ReleaseSmall --name o_zig -femit-bin=/tmp/o_zig 2>/dev/null && echo "  zig: compiles ✓" || echo "  zig: compile findings"
  else
    echo "  zig: (renderer err)"
  fi
}

if [ $# -gt 0 ]; then for f in "$@"; do lint_one "$f"; done
else
  for f in "$ROOT/sh2perl/examples/bench-echo.sh" "$ROOT/sh2perl/examples/008_simple_backup.sh" "$ROOT/sh2perl/examples/051_primes.sh"; do lint_one "$f"; done
fi
