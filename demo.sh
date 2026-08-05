#!/usr/bin/env bash
# demo.sh — exercise every frontend and backend of sh2perl on a set of
# shell examples, showing the shell source file and the tool's output
# side by side with brief commentary.
#
# FRONTENDS (input stages, lexer → lowering):
#   lex        tokenize
#   parse/--ast  parse to AST
#   --mir      Mid-level IR (pre-ShIR, AST-shaped)
#   --shir     language-neutral ShIR (backend contract, A1)
#
# BACKENDS (output targets, generate target code from the IRs):
#   perl      debashc file --perl
#   estree    debashc file --estree (ESTree JSON, JS runtime)
#   js        harness/estree-gen.mjs (ESTree JSON → runnable JS)
#   shir-json debashc file --shir (ShIR JSON, the cross-backend contract)
#   c         c_backend bin (worktree, compiled-in renderer, A2 typed)

set -euo pipefail

ROOT="/nvme/ai/sh2loop"
DEBASHC="$ROOT/sh2perl/target/debug/debashc"
C_BACKEND="$ROOT/sh2perl/backends/c/target/debug/c_backend"
ESTREE_GEN="$ROOT/harness/estree-gen.mjs"

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

# Run a debashc subcommand on a file.
run_debashc() {
  local label="$1" file="$2"; shift 2
  echo "───── $label ─────"
  local out
  out="$("$DEBASHC" "$@" "$file" 2>&1 || true)"
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

# Run c_backend on a file.
run_cbackend() {
  local label="$1" file="$2"
  echo "───── $label ─────"
  local out
  out="$("$C_BACKEND" "$file" 2>&1 || true)"
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

# ESTree JSON → JS via estree-gen.mjs. Pipes the JSON through a tiny
# inline loader (estree-gen.mjs exports `generate` but has no CLI).
run_estree_to_js() {
  local label="$1" file="$2"
  echo "───── $label ─────"
  local out
  out="$(
    "$DEBASHC" file --estree "$file" 2>/dev/null \
      | node --input-type=module -e "import { generate } from '$ESTREE_GEN'; const d = await new Promise(r => { let s=''; process.stdin.on('data',c=>s+=c); process.stdin.on('end',()=>r(JSON.parse(s))); }); process.stdout.write(generate(d));"
  )"
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

  divider "$name — FRONTENDS (input stages)"

  run_debashc "frontend: lex  (tokens)" "$file" lex
  run_debashc "frontend: --ast  (AST tree)" "$file" --ast
  run_debashc "frontend: --mir  (Mid-level IR, AST-shaped)" "$file" --mir
  run_debashc "frontend: --shir  (ShIR, language-neutral, A1 contract)" "$file" --shir

  divider "$name — BACKENDS (output targets)"

  run_debashc "backend: perl  (debashc file --perl)" "$file" file --perl
  run_debashc "backend: estree  (debashc file --estree → JS runtime)" "$file" file --estree
  run_estree_to_js "backend: js  (harness/estree-gen.mjs: ESTree JSON → JS)" "$file"
  run_debashc "backend: shir-json  (debashc file --shir, the contract)" "$file" file --shir
  run_cbackend "backend: c  (worktree c_backend bin, compiled-in renderer)" "$file"
}

# ── write the example files ─────────────────────────────────────────

cat >"$INDIR/ex1_arith.sh" <<'EOF'
x=5
echo $((x * 2))
EOF

cat >"$INDIR/ex2_for.sh" <<'EOF'
for i in 1 2 3; do
  echo "item $i"
done
EOF

cat >"$INDIR/ex3_if_elif.sh" <<'EOF'
x=10
if [ "$x" -gt 100 ]; then
    echo "large"
elif [ "$x" -gt 5 ]; then
    echo "medium"
else
    echo "small"
fi
EOF

cat >"$INDIR/ex4_function.sh" <<'EOF'
greet() {
    local name="$1"
    echo "Hello, $name!"
}
greet "World"
greet "sh2perl"
EOF

divider "sh2perl frontends & backends — demo"
echo "  Tools used:"
echo "    debashc  : $DEBASHC"
echo "    c_backend: $C_BACKEND"
echo "    estree-gen: $ESTREE_GEN"
echo "    inputs   : $INDIR/*.sh"
echo

example "1: assignment + arithmetic + echo"        "$INDIR/ex1_arith.sh"
example "2: for-loop with variable interpolation"  "$INDIR/ex2_for.sh"
example "3: if/elif/else with numeric comparisons" "$INDIR/ex3_if_elif.sh"
example "4: function definition with local var"    "$INDIR/ex4_function.sh"

divider "done"
echo "  STATUS (as of $(date -Iseconds)):"
echo "    sh2perl main:   008c99d  (ESTREE 531/531, PERL 441/90)"
echo "    backend/c:      929bf05  (c_backend bin built; A1-A3/A6 landed)"
echo "    backend/{js,go,python,rust,zig,perl}: worktrees on shared core"
echo
