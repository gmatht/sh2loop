#!/bin/sh
# gpu-static-guard.sh — the naming rule, enforced on every run.
#
# docs/GENERAL-GPU-LIFT.md §6 and docs/MIMECROFT-GPU-PLAN.md §5.1:
# the compiler may name INTERFACES, never PROGRAMS. No transform, pass or
# analysis under sh2perl/src may mention an identifier of the program
# under compilation.
#
# What is scanned: every *.rs under sh2perl/src.
# What is exempt:  comment lines (`//`, `///`, `//!`, `/*`, `*`) and
#                  `#[cfg(test)]` modules (tests and their fixtures are
#                  allowed to spell a program's name — they are the gate's
#                  witnesses, not the compiler).
#
# Forbidden roots: rb_ (the rasterizer's functions), MIME (the game),
# RFB_ / RBTEX (its state), SCOS / SSIN (its bake tables).
#
# The tree does NOT satisfy the rule today: c_backend.rs carries inherited
# fast paths written against one program. Those are budgeted in
# `harness/gpu-static-guard.allow` — a ratchet, not an exemption. The gate
# fails on any NEW coupling (a count over budget, or an unlisted file) and
# passes the inherited debt with a visible summary, so the debt cannot grow
# silently and shrinking it is always allowed.
#
# `grep` in this workspace is a ripgrep FUNCTION and `grep -qF` fails on
# every input, so this script uses awk only. Exit 0 = clean/at-budget,
# 1 = new coupling, 2 = setup problem.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=${1:-"$HERE/../sh2perl/src"}
ALLOW=${2:-"$HERE/gpu-static-guard.allow"}
[ -d "$ROOT" ] || { echo "gpu-static-guard: no such dir: $ROOT" >&2; exit 2; }

# One line per hit: "<file>\t<root>". Classification order is fixed and is
# what the allowlist counts were measured with.
hits=$(find "$ROOT" -name '*.rs' -type f -print | sort | while IFS= read -r f; do
  awk -v file="$(basename "$f")" '
    BEGIN { skip = 0; depth = 0 }
    {
      line = $0
      if (skip) {
        n = gsub(/\{/, "{", line)
        m = gsub(/\}/, "}", line)
        depth += n - m
        if (depth <= 0) { skip = 0; depth = 0 }
        next
      }
      if (line ~ /^[[:space:]]*#\[cfg\(test\)\]/) { skip = 1; depth = 0; next }
      if (line ~ /^[[:space:]]*(\/\/|\/\*|\*)/) next
      code = line
      sub(/\/\/.*$/, "", code)
      if (code ~ /(^|[^A-Za-z0-9_])rb_/)       root = "rb_"
      else if (code ~ /RBTEX/)                  root = "RBTEX"
      else if (code ~ /RFB_/)                   root = "RFB_"
      else if (code ~ /MIME/)                   root = "MIME"
      else if (code ~ /SCOS/)                   root = "SCOS"
      else if (code ~ /SSIN/)                   root = "SSIN"
      else next
      printf "%s\t%s\t%d\t%s\n", file, root, FNR, line
    }
  ' "$f"
done)

# Budgeted counts: "<file> <root> <max>".
budget() {
  [ -f "$ALLOW" ] || return 0
  awk '!/^[[:space:]]*#/ && NF >= 3 { print $1"\t"$2"\t"$3 }' "$ALLOW"
}

new=$(printf '%s\n' "$hits" | BUDGET="$(budget)" awk -F'\t' '
  BEGIN {
    n = split(ENVIRON["BUDGET"], rows, "\n")
    for (i = 1; i <= n; i++) {
      if (rows[i] == "") continue
      split(rows[i], f, "\t")
      max[f[1]"\t"f[2]] = f[3]
    }
  }
  NF >= 2 {
    key = $1"\t"$2
    seen[key]++
    if (!(key in max) || seen[key] > max[key] + 0) print $0
  }
')

debt=$(printf '%s\n' "$hits" | awk -F'\t' 'NF >= 2 { c[$1" "$2]++ } END { for (k in c) printf "%s=%d ", k, c[k] }')

if [ -n "$new" ]; then
  echo "gpu-static-guard: FAIL — new program-name coupling in sh2perl/src:" >&2
  printf '%s\n' "$new" >&2
  echo "gpu-static-guard: inherited debt at budget: ${debt:-none}" >&2
  exit 1
fi

echo "gpu-static-guard: OK — no NEW program identifiers outside comments/tests"
echo "gpu-static-guard: inherited debt (ratchet, only shrinks): ${debt:-none}"
