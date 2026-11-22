#!/bin/sh
# Embedded SPIR-V drift gate (docs/GENERAL-GPU-LIFT.md §6.9).
#
# The runtime executes the bytes in bash-o4/src/fb_spv/*.spv; this gate
# recompiles those shaders from `fb_frag.rs` with the sha256-pinned
# glslang (manifest entry `glslang`) and byte-compares. A mismatch is a
# real error: either the source changed without regenerating, or the
# bytes were edited by hand.
#
#   harness/fb-spv-check.sh             # compare (CI default)
#   harness/fb-spv-check.sh --update    # regenerate bytes + manifest.json
#   SH2_FB_SPV_FETCH=1 …                # allow downloading the pinned asset
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/bash-o4"
if [ "${1:-}" = "--update" ]; then
    SH2_FB_SPV_UPDATE=1 cargo test --test fb_spv_regen -- --nocapture
else
    cargo test --test fb_spv_regen -- --nocapture
fi
