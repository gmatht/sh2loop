#!/usr/bin/env bash
# Usage: verify.sh <transform.rs> <label> [expect_less]
set -e
ROOT=/home/llm/sh2loop
SH2PERL="$ROOT/sh2perl"
SRC="$1"
LABEL="$2"
EXPECT_LESS="${3:-311}"
MOD=$(echo "$LABEL" | tr - _)
VTARGET="$ROOT/.shir-verify-target"
VPT="$SH2PERL/src/transforms.rs"
DST="$SH2PERL/src/transforms/$MOD.rs"
cp "$SRC" "$DST"
python3 - "$MOD" "$LABEL" <<'PY'
import sys
mod, label = sys.argv[1], sys.argv[2]
p = '/home/llm/sh2loop/sh2perl/src/transforms.rs'
t = open(p).read()
if f'pub mod {mod};' not in t:
    t = t.replace('pub mod sub;', f'pub mod {mod};\npub mod sub;', 1)
if f'("{label}"' not in t:
    anchor = '// (name, <name>::transform)'
    t = t.replace(anchor, f'("{label}", {mod}::transform),\n        {anchor}', 1)
open(p,'w').write(t)
PY
echo "building isolated otranspilerl-cli..."
CARGO_TARGET_DIR="$VTARGET" cargo build --manifest-path "$ROOT/otranspilerl/Cargo.toml" --bin otranspilerl-cli 2>&1 | tail -3
VBIN="$VTARGET/debug/otranspilerl-cli"
echo "=== fail-shir (isolated, label=$LABEL) ==="
OTRANSPILERL="$VBIN" SH2_TRANSFORMS="$LABEL" "$ROOT/fail-shir" 2>/dev/null | grep ^SHIR
# restore
git -C "$SH2PERL" checkout -- src/transforms.rs
rm -f "$DST"
