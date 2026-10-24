#!/usr/bin/env bash
# cli-oracle-stale.selftest.sh — regression test for the byte-equality
# oracle-freshness guard used by the frontend gates (`make oracle`).
#
# Pins the TWO failure modes that cost real time on 2026-10-24:
#  1. The predicate must recurse into src/transforms/ (a src/*.rs glob
#     missed the estree worker's fold_param_const WIP there, and the
#     posix-sh-go gate then reported phantom "frontend != core" DIFFs).
#  2. `make oracle` must REBUILD when stale, fall back LOUDLY (not
#     silently) when the core tree does not build, and hard-fail when
#     there is no binary at all.
#
# No cargo, no network, no real workspace: every case builds a sandbox
# tree with explicit mtimes, so the verdict can never depend on the host
# clock or on the state of the shared core.
#
# Usage: harness/cli-oracle-stale.selftest.sh      exit 0 = all pass
set -u

here=$(cd "$(dirname "$0")" && pwd)
chk="$here/cli-oracle-stale.sh"
# The gate Makefile is read from the frontend tree (harness/ is shared, the
# Makefile is the consumer under test).
fe_make="$here/../sh2perl/frontends/posix-sh-go/Makefile"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/oracle-stale-selftest.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok()   { pass=$((pass+1)); echo "PASS  $1"; }
bad()  { fail=$((fail+1)); echo "FAIL  $1"; }
# check <name> <expected-rc> <expected-substring-of-stdout> <args...>
check() {
  name=$1 want_rc=$2 want_sub=$3; shift 3
  out=$(bash "$chk" "$@" 2>/dev/null); rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    bad "$name (rc=$rc want=$want_rc; out='$out')"
  elif [ -n "$want_sub" ] && ! printf '%s' "$out" | command grep -qF -- "$want_sub"; then
    bad "$name (out='$out' lacks '$want_sub')"
  else
    ok "$name"
  fi
}

# --- sandbox workspace ---------------------------------------------------
ws="$tmp/ws"
mkdir -p "$ws/sh2perl/src/parser" "$ws/sh2perl/src/transforms" \
         "$ws/sh2perl/src/shir_passes" "$ws/otranspilerl/src" \
         "$ws/harness"
cp "$chk" "$ws/harness/cli-oracle-stale.sh"
cli="$ws/otranspilerl/target/debug/otranspilerl-cli"
mkdir -p "$(dirname "$cli")"

# Every core source starts OLD; the oracle is NEWER than all of them, so
# the baseline is FRESH and each case ages exactly one thing.
printf '// core\n' > "$ws/sh2perl/src/ir.rs"
printf '// parser\n' > "$ws/sh2perl/src/parser/mod.rs"
printf '// transforms\n' > "$ws/sh2perl/src/transforms/copy_propagation.rs"
printf '// shir_passes\n' > "$ws/sh2perl/src/shir_passes/mod.rs"
printf '// cli\n' > "$ws/otranspilerl/src/main.rs"
printf '// manifest\n' > "$ws/otranspilerl/Cargo.toml"
touch -d '2020-01-01 00:00:00' $(find "$ws/sh2perl" "$ws/otranspilerl" -name '*.rs' -o -name Cargo.toml)
printf '#!/bin/sh\nexit 0\n' > "$cli"; chmod +x "$cli"
touch -d '2024-01-01 00:00:00' "$cli"

echo "--- predicate: harness/cli-oracle-stale.sh ---"
check "fresh oracle -> FRESH (rc 1)" 1 "" "$ws" "$cli"

# CASE 1 — the exact miss: a transform-pass source (one level DEEPER than
# src/*.rs) must stale the oracle. This is fold_param_const's directory.
touch -d '2024-06-01 00:00:00' "$ws/sh2perl/src/transforms/copy_propagation.rs"
check "stale src/transforms/*.rs -> STALE and names the file" 0 "transforms/copy_propagation.rs" "$ws" "$cli"
touch -d '2020-01-01 00:00:00' "$ws/sh2perl/src/transforms/copy_propagation.rs"

# CASE 2 — shir_passes/ is the other deep tree (shIR analyses live there).
touch -d '2024-06-01 00:00:00' "$ws/sh2perl/src/shir_passes/mod.rs"
check "stale src/shir_passes/*.rs -> STALE" 0 "shir_passes/mod.rs" "$ws" "$cli"
touch -d '2020-01-01 00:00:00' "$ws/sh2perl/src/shir_passes/mod.rs"

# CASE 3 — a top-level core source (the case the sibling globs do catch).
touch -d '2024-06-01 00:00:00' "$ws/sh2perl/src/ir.rs"
check "stale src/*.rs -> STALE" 0 "sh2perl/src/ir.rs" "$ws" "$cli"
touch -d '2020-01-01 00:00:00' "$ws/sh2perl/src/ir.rs"

# CASE 4 — the CLI crate's own sources and manifest.
touch -d '2024-06-01 00:00:00' "$ws/otranspilerl/src/main.rs"
check "stale otranspilerl/src/*.rs -> STALE" 0 "otranspilerl/src/main.rs" "$ws" "$cli"
touch -d '2020-01-01 00:00:00' "$ws/otranspilerl/src/main.rs"
touch -d '2024-06-01 00:00:00' "$ws/otranspilerl/Cargo.toml"
check "stale Cargo.toml -> STALE" 0 "Cargo.toml" "$ws" "$cli"
touch -d '2020-01-01 00:00:00' "$ws/otranspilerl/Cargo.toml"

# CASE 5 — absent / non-executable oracle is stale (a 0644 cp once made
# every snapshot verify "Permission denied"; same class).
mv "$cli" "$cli.real"
check "missing oracle -> STALE" 0 "missing" "$ws" "$cli"
cp "$cli.real" "$cli"; chmod -x "$cli"
check "non-executable oracle -> STALE" 0 "missing" "$ws" "$cli"
chmod +x "$cli"; touch -d '2024-01-01 00:00:00' "$cli"

# CASE 6 — usage error is its own verdict, never "fresh".
bash "$chk" "$ws" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "no args -> rc 2 (usage)" || bad "no args -> rc 2 (got $rc)"

# --- make recipe: `make oracle` ----------------------------------------
# CARGO is overridden so no real build runs: `true` = a build that
# succeeds, `false` = a mid-WIP core tree that does not.
if ! command -v make >/dev/null 2>&1 || [ ! -f "$fe_make" ]; then
  echo "SKIP  make-recipe cases (make or $fe_make unavailable)"
else
  echo "--- recipe: make oracle ---"
  sandbox="$tmp/sandbox"
  mkdir -p "$sandbox/frontends/posix-sh-go" "$sandbox/harness" \
           "$sandbox/otranspilerl/src" "$sandbox/sh2perl/src/transforms"
  # WS_ROOT is found by walking up for otranspilerl/Cargo.toml, so the
  # sandbox needs that marker + the helper + the real Makefile.
  printf '[package]\nname="x"\n' > "$sandbox/otranspilerl/Cargo.toml"
  printf '// core\n' > "$sandbox/sh2perl/src/transforms/copy_propagation.rs"
  cp "$chk" "$sandbox/harness/cli-oracle-stale.sh"
  cp "$fe_make" "$sandbox/frontends/posix-sh-go/Makefile"
  scli="$sandbox/otranspilerl/target/debug/otranspilerl-cli"
  mkdir -p "$(dirname "$scli")"
  printf '#!/bin/sh\nexit 0\n' > "$scli"; chmod +x "$scli"

  # Fresh: no rebuild, no output about the oracle at all.
  touch -d '2020-01-01 00:00:00' "$sandbox/sh2perl/src/transforms/copy_propagation.rs"
  touch -d '2020-01-01 00:00:00' "$sandbox/otranspilerl/Cargo.toml"
  touch -d '2024-01-01 00:00:00' "$scli"
  out=$(cd "$sandbox/frontends/posix-sh-go" && make -s oracle CARGO=true 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | command grep -qE 'STALE|rebuilding'; then
    ok "recipe: fresh oracle is a no-op"
  else
    bad "recipe: fresh oracle is a no-op (rc=$rc out='$out')"
  fi

  # Stale + a build that succeeds: reports WHY, then rebuilds.
  touch -d '2025-01-01 00:00:00' "$sandbox/sh2perl/src/transforms/copy_propagation.rs"
  out=$(cd "$sandbox/frontends/posix-sh-go" && make -s oracle CARGO=true 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | command grep -q 'STALE' \
     && printf '%s' "$out" | command grep -q 'rebuilt'; then
    ok "recipe: stale + CARGO=true -> STALE diagnostic, then rebuilt"
  else
    bad "recipe: stale + CARGO=true (rc=$rc out='$out')"
  fi

  # Stale + a mid-WIP core that does NOT build: must not wedge the gate,
  # must not be silent, and must re-arm (stamp) so the next change retries.
  # CARGO=true above is a STUB: it reports success without relinking, so the
  # source must be re-aged here or this case would silently run FRESH.
  touch -d '2025-01-01 00:00:00' "$sandbox/sh2perl/src/transforms/copy_propagation.rs"
  out=$(cd "$sandbox/frontends/posix-sh-go" && make -s oracle CARGO=false 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | command grep -q 'WARNING: oracle rebuild FAILED'; then
    ok "recipe: stale + broken core -> WARNING, rc 0 (no wedge)"
  else
    bad "recipe: stale + broken core (rc=$rc out='$out')"
  fi
  out=$(cd "$sandbox/frontends/posix-sh-go" && make -s oracle CARGO=false 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | command grep -q 'STALE'; then
    ok "recipe: fallback stamps the binary (rule re-arms on next change)"
  else
    bad "recipe: fallback stamps the binary (rc=$rc out='$out')"
  fi

  # No binary at all + a core that does not build: hard error, no guess.
  rm -f "$scli"
  out=$(cd "$sandbox/frontends/posix-sh-go" && make -s oracle CARGO=false 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | command grep -q 'ERROR: no otranspilerl-cli'; then
    ok "recipe: no binary + broken core -> ERROR, non-zero"
  else
    bad "recipe: no binary + broken core (rc=$rc out='$out')"
  fi
fi

echo
echo "[cli-oracle-stale] $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
