#!/usr/bin/env bash
# all_build.sh — build everything all_failures.sh needs.
#
# all_failures.sh measures equivalence across backends and assumes these
# artifacts already exist (it builds nothing itself):
#   1. otranspilerl-cli      otranspilerl/target/debug/otranspilerl-cli
#      (HARD requirement — all_failures exits 2 without it)
#   2. shir_render           sh2perl/backends/<lang>/target/debug/shir_render
#      per backend (perl estree c rust python go zig sh java fish).
#      This checkout has no per-backend worktrees there, so the single core
#      renderer (sh2perl/src/bin/shir_render.rs) is built once and installed
#      into each expected path. Backends with a direct-render fallback in
#      all_failures (all except fish) work even without it; fish has NO
#      direct fallback, so without this step fish is "not measured".
#   3. node runtime files    harness/estree-runner.mjs (+ vendored
#      estree-gen.mjs, sh2-namespace.mjs — no npm install needed)
#   4. uu-ffi shared lib     sh2perl/runtime/lib/libcoreutils_ffi.so
#      (OPTIONAL — C/Zig runs use it only `if [ -f ... ]`, else fall back)
#   5. toolchains             perl node cc rustc python3 go zig javac/java
#      fish sh (checked, never installed — report only)
#
# Usage:
#   ./all_build.sh [--check] [-j N]
#     --check  verify artifacts exist, build nothing (exit 1 if missing)
#     -j N     cargo build jobs (default: nproc)
#
# Idempotent: re-running rebuilds (cargo is incremental) and re-installs
# the per-backend shir_render copies.
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
OTRANS_MANIFEST="$ROOT/otranspilerl/Cargo.toml"
OTRANS_BIN="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
CORE_MANIFEST="$ROOT/sh2perl/Cargo.toml"
CORE_RENDER_BIN="$ROOT/sh2perl/target/debug/shir_render"
RUNNER="$ROOT/harness/estree-runner.mjs"
CAPCMD="$ROOT/harness/cap-capture.pl"
KS="$ROOT/harness/kill-session.sh"
UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
BACKENDS="perl estree c rust python go zig sh java fish"
JOBS="$(nproc 2>/dev/null || echo 4)"
CHECK_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift;;
    -j|--jobs) JOBS="$2"; shift 2;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "all_build: unknown arg '$1' (see --help)" >&2; exit 2;;
  esac
done

fail=0
have() { command -v "$1" >/dev/null 2>&1; }

# --check: verify everything, build nothing.
if [ "$CHECK_ONLY" = 1 ]; then
  [ -x "$OTRANS_BIN" ] || { echo "all_build --check: MISSING $OTRANS_BIN" >&2; fail=1; }
  for lang in $BACKENDS; do
    [ -x "$ROOT/sh2perl/backends/$lang/target/debug/shir_render" ] \
      || { echo "all_build --check: MISSING shir_render for [$lang]" >&2; fail=1; }
  done
  [ -f "$RUNNER" ] || { echo "all_build --check: MISSING $RUNNER" >&2; fail=1; }
  [ -f "$CAPCMD" ] || { echo "all_build --check: MISSING $CAPCMD" >&2; fail=1; }
  [ -f "$UU_LIB" ] || echo "all_build --check: optional $UU_LIB absent (C/Zig fall back)" >&2
  for t in perl node cc rustc python3 go zig javac java fish sh; do
    have "$t" || { echo "all_build --check: no toolchain '$t'" >&2; fail=1; }
  done
  [ "$fail" = 0 ] && echo "all_build --check: all artifacts present"
  exit "$fail"
fi

export CARGO_BUILD_JOBS="$JOBS"

echo "all_build: [1/4] otranspilerl-cli (all_failures hard requirement)" >&2
if cargo build --manifest-path "$OTRANS_MANIFEST" --bin otranspilerl-cli; then
  echo "all_build: built $OTRANS_BIN" >&2
else
  echo "all_build: FAILED to build otranspilerl-cli — all_failures cannot run" >&2
  exit 1
fi

echo "all_build: [2/4] core shir_render -> per-backend install paths" >&2
if cargo build --manifest-path "$CORE_MANIFEST" --bin shir_render; then
  for lang in $BACKENDS; do
    dest="$ROOT/sh2perl/backends/$lang/target/debug/shir_render"
    mkdir -p "$(dirname "$dest")"
    cp -f "$CORE_RENDER_BIN" "$dest"
    chmod +x "$dest"
  done
  echo "all_build: installed shir_render for: $BACKENDS" >&2
  echo "all_build: note: shir_render has no 'fish' target (exits 3); fish renders" >&2
  echo "all_build: note: direct via otranspilerl --target fish, which does support it" >&2
else
  echo "all_build: FAILED to build core shir_render" >&2
  echo "all_build: continuing — backends with a direct-render fallback" >&2
  echo "all_build: (all except fish) still work; fish will be 'not measured'" >&2
fi

echo "all_build: [3/4] node runtime files (vendored, verify only)" >&2
for f in "$RUNNER" "$ROOT/harness/estree-gen.mjs" "$ROOT/harness/sh2-namespace.mjs" "$CAPCMD" "$KS"; do
  if [ -f "$f" ]; then
    echo "all_build: ok $f" >&2
  else
    echo "all_build: MISSING $f" >&2
    fail=1
  fi
done
[ -x "$KS" ] || chmod +x "$KS" 2>/dev/null || true

echo "all_build: [4/4] uu-ffi shared lib (optional)" >&2
if [ -f "$UU_LIB" ]; then
  echo "all_build: ok $UU_LIB (present)" >&2
elif [ -x "$ROOT/sh2perl/runtime/build_uu_ffi.sh" ] && [ -d "${UU_FFI_DIR:-/root/src/coreutils/uu-ffi}" ]; then
  if bash "$ROOT/sh2perl/runtime/build_uu_ffi.sh"; then
    echo "all_build: built $UU_LIB" >&2
  else
    echo "all_build: uu-ffi build failed — C/Zig fall back (not fatal)" >&2
  fi
else
  echo "all_build: no uu-ffi source (sh2perl/runtime/build_uu_ffi.sh needs" >&2
  echo "all_build: /root/src/coreutils/uu-ffi) — C/Zig fall back (not fatal)" >&2
fi

echo "all_build: toolchain probe (report only, never installed)" >&2
for t in perl node cc rustc python3 go zig javac java fish sh; do
  if have "$t"; then
    echo "all_build: tool ok: $t ($({ command -v "$t"; } 2>/dev/null))" >&2
  else
    echo "all_build: tool MISSING: $t (that backend will be 'not measured')" >&2
  fi
done

if [ "$fail" != 0 ]; then
  echo "all_build: required harness files missing (see above)" >&2
  exit 1
fi
echo "all_build: done — ./all_failures.sh is ready to run" >&2
