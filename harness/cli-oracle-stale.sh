#!/usr/bin/env bash
# cli-oracle-stale.sh <workspace-root> <cli-binary>
#
# Is the byte-equality ORACLE stale? otranspilerl-cli statically links the
# debashl core, so the binary must be at least as new as the checked-out
# core sources it is supposed to represent.
#
#   0  STALE (or missing) — prints the newest offending path (first line)
#   1  FRESH
#   2  usage error
#
# WHY (2026-10-24, posix-sh-go): `make test` compares the frontend's A1
# emit against `otranspilerl-cli --source-lang sh --target shir --raw`.
# When the binary predates the sources, that comparison is against a
# DIFFERENT program than the one in the tree — and every mismatch prints
# the same line as a real frontend gap:
#
#   DIFF t04_params.sh (frontend != core — the gap the worker fixes)
#
# The estree worker's uncommitted `fold_param_const` WIP (+641 lines in
# sh2perl/src/transforms/copy_propagation.rs) sat in the worktree while the
# published CLI predated it. t04_params and t07_reassign each reported a
# phantom DIFF that six AI invocations (each exhausting its turn budget)
# tried to "fix"; both went byte-equal the instant the CLI was rebuilt.
#
# NOTE the recursion: a `src/*.rs` + `src/parser/*.rs` glob (the shape the
# sibling Makefiles use for their CORE_SRC prerequisite) misses
# src/transforms/, src/shir_passes/ and src/render_ext*/ — which is exactly
# where that WIP lived. Hence `find` from src rather than a wildcard list.
set -u
if [ $# -ne 2 ]; then
  echo "usage: cli-oracle-stale.sh <workspace-root> <cli-binary>" >&2
  exit 2
fi
ws=$1
cli=$2

# A missing or non-executable oracle is stale by definition: the gate
# cannot compare a byte against it.
if [ ! -x "$cli" ]; then
  echo "missing $cli"
  exit 0
fi

# Newest source that postdates the binary; -quit stops at the first hit so
# a stale tree costs one stat per candidate, not a full walk of both src/.
# The manifests are named EXPLICITLY: they live at the crate root, which is
# not under either src/ root, so a find over the src trees can never see
# them (caught by this script's selftest). Absent paths are harmless.
newest=$(
  find "$ws/sh2perl/src" "$ws/otranspilerl/src" \
       "$ws/Cargo.toml" "$ws/Cargo.lock" \
       "$ws/sh2perl/Cargo.toml" "$ws/otranspilerl/Cargo.toml" \
       -type f \( -name '*.rs' -o -name 'Cargo.toml' -o -name 'Cargo.lock' \) \
       -newer "$cli" -print -quit 2>/dev/null
)
if [ -n "$newest" ]; then
  echo "$newest"
  exit 0
fi
exit 1
