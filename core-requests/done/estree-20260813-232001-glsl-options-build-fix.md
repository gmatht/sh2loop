# estree: fix the wasi-lib build break (ShGlslOptions max_view/vert_out) + make max_view embedder-owned

## NEED

Two linked fixes in the shared core:

1. **BUILD BREAK**: `sh2perl/src/wasi_api.rs` (`debashc_to_glsl`) still
   constructs `ShGlslOptions { es100: true, color_out: true, tex_size:
   16 }` without the new `max_view`/`vert_out` fields the mediation
   added — `cargo build --features wasi-lib` fails with E0063 (the
   debashl/debashcl/debashc wasm builds are all blocked). The
   mediation updated the otranspilerl crate's callers but missed this
   one.
2. **DESIGN**: the fragment/vertex entries hardcode `max_view: 800`
   ("the sh2runtime device canvas is 800×600"). `max_view` is the
   frag_x/frag_y coordinate range used by the backend's range analysis
   — it is an EMBEDDER parameter (the canvas the shader runs on), not
   a core constant. The core must not bake in a browser size.

## WHY

The browser game's shaders are authored for an 800×600 canvas (the
frag program writes `vx=$((fx - 400))` — half of 800), so the generator
must be told the coordinate range; baking 800 into the wasm ties the
core to one embedder. And the wasi-lib build break blocks every wasm
artifact (debashcl.wasm is the browser's `bash script.sh` engine).

## MINIMAL-CORE-CHANGE

1. `src/wasi_api.rs` `debashc_to_glsl`: add the missing fields —
   `..Default::default()` (max_view: 0 — no viewport math; this legacy
   frag entry is unused by the browser, which goes through the
   otranspilerl crate).
2. **Parameterize `max_view` in the C-ABI**: `otranspilerl_glsl(input,
   input_len, view: i32)` and `otranspilerl_glslv(input, input_len,
   view: i32)` in the otranspilerl crate — `max_view: view.max(0) as
   u32`. The sh2runtime side (src/otranspilerl.js) passes its canvas
   width (800) per call; the shader AUTHOR agrees the frag program's
   coordinate space with the same value. No core constant.

## FAILING-CASE

    cargo build --release --target wasm32-wasip1 -p debashl --features wasi-lib --lib

currently fails: `error[E0063]: missing fields max_view and vert_out in
initializer of ShGlslOptions` (src/wasi_api.rs:132). After the fix it
builds, and `sh2glsl`/`sh2glsl --vertex` produce identical output with
the view passed from the embedder (the shader-test gate asserts the
generated shaders validate as ES 1.00).

## OUTCOME: implemented — this round removed the hardcoded `max_view: 800` from wasi_api.rs debashc_to_glsl (`..Default::default()` → 0); the otranspilerl `otranspilerl_glsl`/`otranspilerl_glslv` C-ABI entries already take the embedder-passed `view: i32` (`max_view: view.max(0)`). Verified: `cargo build --release --target wasm32-wasip1 -p debashl --features wasi-lib --lib` and the otranspilerl wasm build both succeed (E0063 gone).
