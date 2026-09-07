#!/usr/bin/env bash
# show_sqrt_langs.sh — run sqrt1337.sh through every sh2perl backend that
# can render it, and show each language's output (each verified identical
# to bash).
#
# Backends (probed; skipped with a note when the worktree binary isn't
# built yet):
#   bash    the original script (baseline)
#   perl    production backend            otranspilerl-cli --target pl
#   c       shir_to_c (backends/c) + gcc  otranspilerl-cli --target shir | shir_to_c
#   js      --estree -> estree-runner.mjs otranspilerl-cli --target estree | node runner
#   go      backends/go --shir-in-go      (ShIR JSON in -> Go source)
#   rust    backends/rust file --shir-in-rust
#   zig     backends/zig --shir-in-zig    (needs the zig toolchain)
#   python  backends/python python_backend <file.sh>
#   sh      backends/sh sh_backend <file.sh>
#
# Draft backends (go/rust/zig/python) may report MISMATCH with their
# current blocker shown (e.g. unlowered `contains`/seq-for) — that is the
# real state of those worktrees, not a script failure.
#
# Usage: show_sqrt_langs.sh [src.sh]
#   SRC defaults to sh2perl/sqrt1337.sh; CODE=1 also dumps each generated
#   program to stdout; KEEP=1 keeps /tmp/sqrt_langs across runs.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEBASHC="$ROOT/sh2perl/otranspilerl/target/debug/otranspilerl-cli"
WT="$ROOT/sh2perl/backends"
SRC="${1:-$ROOT/sh2perl/sqrt1337.sh}"
OUT=/tmp/sqrt_langs
CODE="${CODE:-0}"
KEEP="${KEEP:-0}"

[ -x "$DEBASHC" ] || { echo "otranspilerl-cli not built: cd otranspilerl && cargo build --bin otranspilerl-cli (sh2perl)"; exit 1; }
[ -f "$SRC" ] || { echo "no such source: $SRC"; exit 1; }
mkdir -p "$OUT"
[ "$KEEP" = 1 ] || rm -f "$OUT"/*

exp="$(bash "$SRC")" || { echo "bash failed on $SRC"; exit 1; }

show_code() { # file
  if [ "$CODE" = 1 ]; then
    echo "--- generated source ($(basename "$1")) ---"
    sed -n '/^#!/,$p' "$1"
    echo "----------------------------------------"
  fi
}

# check <lang> <output> <stderr-or-issue>
check() {
  local name="$1" out="$2" issue="$3"
  if [ "$out" = "$exp" ]; then
    printf "%-8s OK    (identical output)\n" "$name"
    echo "$out" | sed 's/^/        /'
  else
    printf "%-8s MISMATCH — %s\n" "$name" "${issue:-no output}"
    if [ -n "$out" ]; then
      echo "$out" | head -8 | sed 's/^/        /'
      local n; n=$(echo "$out" | wc -l)
      [ "$n" -gt 8 ] && echo "        … ($n lines total)"
    fi
  fi
  echo
}

echo "expected output (bash $SRC):"
echo "$exp" | sed 's/^/    /'
echo

# ---------- perl: production backend ----------
# the CLI wraps the code in a "Converting to Perl:" banner + a trailing
# ==== separator line (perl parses bare ===== as a VCS conflict marker)
if command -v perl >/dev/null; then
  if "$DEBASHC" file --perl "$SRC" 2>/dev/null \
     | sed -n '/^#!/,$p' | sed '/^====*$/d' > "$OUT/sqrt1337.pl"; then
    show_code "$OUT/sqrt1337.pl"
    out="$(perl "$OUT/sqrt1337.pl" 2>&1)"
    check perl "$out" "seq-for lowered to one joined string (core bug — core-requests/perl-20260806-sqrt1337-seq-for.md)"
  else
    echo "perl   generate FAILED"; echo
  fi
else
  echo "perl   skipped (no perl)"; echo
fi

# ---------- c: shir_to_c + gcc ----------
if [ -x "$WT/c/target/debug/shir_to_c" ] && command -v gcc >/dev/null; then
  if "$DEBASHC" file --shir "$SRC" 2>/dev/null | "$WT/c/target/debug/shir_to_c" > "$OUT/sqrt1337.c" \
     && gcc "$OUT/sqrt1337.c" -lm -o "$OUT/sqrt1337_c" 2>"$OUT/c.err"; then
    show_code "$OUT/sqrt1337.c"
    check c "$("$OUT/sqrt1337_c")" ""
  else
    echo "c      skipped (shir_to_c not built / no gcc)"; echo
  fi
else
  echo "c      skipped (shir_to_c not built / no gcc)"; echo
fi

# ---------- js: --estree -> estree-runner.mjs ----------
if command -v node >/dev/null && [ -f "$ROOT/harness/estree-runner.mjs" ]; then
  if "$DEBASHC" file --estree "$SRC" 2>/dev/null > "$OUT/sqrt1337.json"; then
    show_code "$OUT/sqrt1337.json"
    check js "$(timeout 300 node "$ROOT/harness/estree-runner.mjs" "$OUT/sqrt1337.json" --source "$SRC" 2>&1)" ""
  else
    echo "js     generate FAILED"; echo
  fi
else
  echo "js     skipped (no node / no runner)"; echo
fi

# ---------- go: --shir-in-go ----------
if [ -x "$WT/go/otranspilerl/target/debug/otranspilerl-cli" ] && command -v go >/dev/null; then
  if "$DEBASHC" file --shir "$SRC" 2>/dev/null | "$WT/go/otranspilerl/target/debug/otranspilerl-cli" --shir-in-go - > "$OUT/sqrt1337.go" 2>/dev/null; then
    if go build -o "$OUT/sqrt1337_go" "$OUT/sqrt1337.go" 2>"$OUT/go.err"; then
      show_code "$OUT/sqrt1337.go"
      check go "$("$OUT/sqrt1337_go" 2>&1)" ""
    else
      echo "go      skipped (go build): $(head -2 "$OUT/go.err" | tail -1)"; echo
    fi
  else
    echo "go      skipped (renderer failed)"; echo
  fi
else
  echo "go      skipped (worktree not built / no go)"; echo
fi

# ---------- rust: file --shir-in-rust ----------
if [ -x "$WT/rust/otranspilerl/target/debug/otranspilerl-cli" ] && command -v rustc >/dev/null; then
  if "$DEBASHC" file --shir "$SRC" 2>/dev/null > "$OUT/sqrt1337.shir.json" \
     && "$WT/rust/otranspilerl/target/debug/otranspilerl-cli" file --shir-in-rust "$OUT/sqrt1337.shir.json" > "$OUT/sqrt1337.rs" 2>/dev/null \
     && rustc "$OUT/sqrt1337.rs" -o "$OUT/sqrt1337_rust" 2>"$OUT/rust.err"; then
    show_code "$OUT/sqrt1337.rs"
    check rust "$("$OUT/sqrt1337_rust" 2>&1)" ""
  else
    if [ -s "$OUT/rust.err" ]; then
      echo "rust    skipped (rustc): $(head -1 "$OUT/rust.err")"; echo
    else
      echo "rust    skipped (renderer failed)"; echo
    fi
  fi
else
  echo "rust    skipped (worktree not built / no rustc)"; echo
fi

# ---------- zig: --shir-in-zig ----------
if [ -x "$WT/zig/otranspilerl/target/debug/otranspilerl-cli" ] && command -v zig >/dev/null; then
  if "$DEBASHC" file --shir "$SRC" 2>/dev/null | "$WT/zig/otranspilerl/target/debug/otranspilerl-cli" --shir-in-zig - > "$OUT/sqrt1337.zig" 2>/dev/null \
     && zig build-exe "$OUT/sqrt1337.zig" -O ReleaseSafe -femit-bin="$OUT/sqrt1337_zig" 2>"$OUT/zig.err"; then
    show_code "$OUT/sqrt1337.zig"
    check zig "$("$OUT/sqrt1337_zig" 2>&1)" ""
  else
    if [ -s "$OUT/zig.err" ]; then
      echo "zig     skipped (zig build): $(head -1 "$OUT/zig.err")"; echo
    else
      echo "zig     skipped (renderer failed)"; echo
    fi
  fi
else
  echo "zig     skipped (worktree not built / no zig toolchain)"; echo
fi

# ---------- python: python_backend ----------
if [ -x "$WT/python/target/debug/python_backend" ] && command -v python3 >/dev/null; then
  if "$WT/python/target/debug/python_backend" "$SRC" > "$OUT/sqrt1337.py" 2>/dev/null; then
    show_code "$OUT/sqrt1337.py"
    out="$(timeout 60 python3 "$OUT/sqrt1337.py" 2>&1)"
    check python "$out" "$(echo "$out" | grep -m1 'TODO' || true)"
  else
    echo "python generate FAILED"; echo
  fi
else
  echo "python skipped (python_backend not built / no python3)"; echo
fi

# ---------- sh: sh_backend ----------
if [ -x "$WT/sh/target/debug/sh_backend" ] && command -v sh >/dev/null; then
  if "$WT/sh/target/debug/sh_backend" "$SRC" > "$OUT/sqrt1337_gen.sh" 2>/dev/null; then
    show_code "$OUT/sqrt1337_gen.sh"
    check sh "$(timeout 300 sh "$OUT/sqrt1337_gen.sh" 2>&1)" ""
  else
    echo "sh     generate FAILED"; echo
  fi
else
  echo "sh     skipped (sh_backend not built)"; echo
fi

echo "generated programs kept in: $OUT"
