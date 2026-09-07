#!/usr/bin/env bash
# snapshot-otranspilerl-cli.sh <src-binary> <dst-path>
#
# Copy the otranspilerl-cli oracle binary to a private per-gate path and VERIFY it
# functionally (--shir-in-estree on a minimal A1 program must exit 0).
# Exits 0 with a verified snapshot at <dst-path>; exits 1 if no good
# binary is obtainable within the retry window.
#
# WHY: otranspilerl/target/debug/otranspilerl-cli is a shared, racy resource. The estree worker
# rebuilds it while implementing core requests, and any frontend gate's
# self-heal rule (`$(DEBASHC):` in the Makefiles) rebuilds it when it goes
# missing; two concurrent cargo builds on one target dir can leave the
# file truncated/absent/torn for seconds (estree worker log: "the binary
# is GONE", "binary was replaced under me", "the run raced with
# concurrent rebuilds"). A gate that invokes the shared binary 80+ times
# can hit the bad window exactly once and fail with a misleading
# "FAIL <file> (A1 -> ESTree conversion)" (zsh-sh-go t71_var_name_mods,
# 2026-08-12 20:55:24; fish-sh-go t40_nested_loop 18:04; go-sh
# t02_assign_str). A gate that copies once at start — with a functional
# check — sees ONE stable binary for its whole run; a genuinely
# unavailable oracle fails fast with a clear message instead of a random
# per-test failure.
set -u
src=$1
dst=$2
min="$dst.min-a1.json"
cat > "$min" <<'EOF'
{"contract_version":1,"imports":[],"requires":[],"stmt_lines":[],"stmts":[],"subs":[],"type":"Program","var_bash_env":[],"var_const":[],"var_lengths":[],"var_lifetimes":[],"var_nospace":[],"var_types":[]}
EOF
for _try in $(seq 1 30); do
  # cp over a pre-existing destination PRESERVES the destination mode
  # (a 644 source leaves a non-executable copy, failing every verify
  # with "Permission denied"); force the exec bit explicitly.
  if cp "$src" "$dst" 2>/dev/null && chmod +x "$dst" 2>/dev/null && "$dst" --shir-in-estree "$min" > /dev/null 2>&1; then
    rm -f "$min"
    exit 0
  fi
  sleep 3
done
rm -f "$min"
echo "snapshot-otranspilerl-cli.sh: no verified binary at '$src' after ~90s (concurrent cargo relink?)" >&2
exit 1
