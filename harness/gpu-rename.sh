#!/bin/sh
# gpu-rename.sh — the generality gate for the GPU lift.
#
# docs/GENERAL-GPU-LIFT.md §"Gates", gate 1 and gate 2. It runs the
# witness/rename/negative-control tests from `sh2perl/src/shir_passes/
# gpu_lift/` and then the static name guard. The rename test rewrites
# every identifier the second-witness program owns to a `zz_` prefix and
# requires identical verdicts and identical shaders modulo that prefix:
# a transform keyed on a name fails it immediately.
#
# Why the test is Rust and this file is thin: the verdicts are a library
# API (`shir_passes::gpu_lift::analyze`), so the rename comparison runs
# in-process against the same parser the compiler uses. Re-implementing
# the parse in shell would test a different thing.
#
# Usage: harness/gpu-rename.sh [--quiet]
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

say() { [ "$QUIET" = 1 ] || echo "$@"; }

say "gpu-rename: verdicts + rename gate (sh2perl gpu_lift tests)"
if [ "$QUIET" = 1 ]; then
  cargo test --manifest-path "$ROOT/sh2perl/Cargo.toml" --lib \
    shir_passes::gpu_lift::tests >/dev/null 2>&1
else
  cargo test --manifest-path "$ROOT/sh2perl/Cargo.toml" --lib \
    shir_passes::gpu_lift::tests
fi

say "gpu-rename: static name guard"
sh "$ROOT/harness/gpu-static-guard.sh"

say "gpu-rename: OK — the lift recognises the witness by contract, not by name"
