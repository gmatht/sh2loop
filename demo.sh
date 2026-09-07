#!/usr/bin/env bash
# demo.sh — exercise the transpiler pipeline on a set of shell examples,
# showing the shell source file and the tool's output side by side with
# brief commentary.
#
# PIPELINE (the otranspilerl-cli flow: parse → A1 shIR → target):
#   --target shir    language-neutral ShIR JSON (the A1 cross-backend contract)
#   --target pl      Perl
#   --target estree  ESTree JSON (the sh2.* JS-runtime contract)
#   --target js      ESTree → real JavaScript source (the estree-gen printer)
#   --target c       C
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OTRANS="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
SHIR_RENDER="$ROOT/sh2perl/target/debug/shir_render"

MAX_LINES=25
INDIR="$ROOT/.demo-examples"
mkdir -p "$INDIR"

divider() {
  echo
  printf '══════════════════════════════════════════════════════════════════\n'
  printf '  %s\n' "$1"
  printf '══════════════════════════════════════════════════════════════════\n'
  echo
}

show_input() {
  local file="$1"
  echo "  ┌── input: $file ──"
  # number lines for easy reference
  awk '{ printf("  │ %2d  %s\n", NR, $0) }' "$file"
  echo "  └──────────────────"
  echo
}

# Run a tool on a file, truncate long output.
run() {
  local label="$1"; shift
  echo "───── $label ─────"
  local out
  out="$("$@" 2>&1 || true)"
  local n
  n=$(printf '%s\n' "$out" | wc -l)
  if [ "$n" -le "$MAX_LINES" ]; then
    printf '%s\n' "$out"
  else
    printf '%s\n' "$out" | head -n "$MAX_LINES"
    echo "  … (truncated: $n lines total)"
  fi
  echo
}

example() {
  local name="$1" file="$2"
  divider "EXAMPLE: $name"
  show_input "$file"

  divider "$name — PIPELINE (parse → A1 → targets)"

  run "stage: A1 shIR  (the language-neutral contract)" "$OTRANS" --target shir "$file"
  run "backend: perl  (--target pl)" "$OTRANS" --target pl "$file"
  run "backend: estree  (--target estree, the JS-runtime contract)" "$OTRANS" --target estree "$file"
  run "backend: js  (--target js, the estree-gen printer)" "$OTRANS" --target js "$file"
  run "backend: c  (shir_render --target c, the worktree gate entry)" "$SHIR_RENDER" --target c < <("$OTRANS" --target shir "$file" 2>/dev/null)
}

# ── write the example files ─────────────────────────────────────────

cat >"$INDIR/ex1_arith.sh" <<'EOF'
x=5
echo $((x * 2))
EOF

cat >"$INDIR/ex2_control.sh" <<'EOF'
for i in 1 2 3; do
  if [ "$i" -gt 1 ]; then
    echo "i=$i is big"
  fi
done
EOF

cat >"$INDIR/ex3_string.sh" <<'EOF'
name="world"
echo "hello, ${name}!"
echo ${name^^}
EOF

# ── run the demos ───────────────────────────────────────────────────

for f in "$INDIR"/*.sh; do
  example "$(basename "$f" .sh)" "$f"
done
