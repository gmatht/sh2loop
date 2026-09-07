# otranspilerl

The Rust port of the Go `otranspiler` wrapper: one library that statically
links the `sh2perl core` core (shell → A1 shIR) and **all nine backend renderers**
(c, go, java, js/estree, perl, python, rust, sh, zig) into a single artifact
exposing the full otranspiler functionality — including the CLI, so the CLI
binary is a three-line wrapper. Builds natively (rlib + cdylib + bin) and to
WASM (`wasm32-wasip1`).

## Build

```sh
cd otranspilerl
cargo build                        # native: libotranspilerl.{rlib,so} + target/debug/otranspilerl-cli
cargo build --target wasm32-wasip1 # wasm:    target/wasm32-wasip1/debug/otranspilerl.wasm
```

The CLI binary is a three-line wrapper around the library:

```sh
./target/debug/otranspilerl-cli <input> [<output>] [flags]   # same interface as the Go otranspiler
```

## Rebuilding after backend changes

The renderers live in two places:

- the **worktrees** `../sh2perl/backends/<lang>/` on `backend/<lang>`
  branches (where backend work happens), and
- the **merged copies** `../sh2perl/src/<lang>_backend.rs` in the core,
  which otranspilerl actually links against.

Backend changes made in a worktree do **not** flow into otranspilerl
automatically — the merged renderer must be re-copied (and adapted) into
`../sh2perl/src/*_backend.rs` first. Once that's done, `cargo build` picks up
the `sh2perl core` path dependency automatically:

```sh
cd otranspilerl && cargo build          # native (recompiles the sh2perl core crate path dep)
cargo build --target wasm32-wasip1      # wasm
```

## WASM C-ABI

The wasm build is a reactor exporting the library ABI (`otranspilerl_alloc`,
`otranspilerl_shir`, `otranspilerl_render`, `otranspilerl_transpile`,
`otranspilerl_cli`, `otranspilerl_str_len`, `otranspilerl_free`). String
buffers follow the sh2perl core crate contract: `[u32 data_len LE][data][0]`, inputs
written via `otranspilerl_alloc`. See `src/wasi.rs`.

## Known limitation

The non-shell source frontends (py/c/pl/zsh/fish/go → A1) and `--run` exec a
process; the native build uses `std::process` behind the `run_process`/`run_estree`
seams, but the wasm build has no process spawn yet (WASIX/Wasmer bind pending) and
returns a clear error — feed those frontends' A1 JSON via `-`/`.shir` or
`otranspilerl_render` instead.
