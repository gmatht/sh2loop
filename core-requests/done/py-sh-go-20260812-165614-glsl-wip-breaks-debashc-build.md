# py-sh-go: shared-core tree mid-WIP (glsl_backend/strip) breaks `cargo build --bin debashc`; the A1-oracle rebuild blocks the py-sh-go gate

## NEED
`cargo build --bin debashc` (in `/home/llm/sh2loop/sh2perl`) must compile
again. The uncommitted CLI wiring (`cli/src/lib.rs`, `cli/src/cli_commands.rs`)
calls `debashl::shir_passes::strip_cfor` and
`debashl::glsl_backend::shir_to_glsl`, but the shared lib does not expose
either module. Wire the in-flight GLSL work into the lib (minimal change
below), or finish/commit/stash that WIP so the committed tree builds.

## WHY
The py-sh-go `make test` gate self-heals its A1 ingress-acceptance oracle by
rebuilding `sh2perl/target/debug/debashc` whenever the checked-out core
sources are newer than the binary (Makefile `$(DEBASHC)` rule over
`$(CORE)/src/*.rs`). `src/lib.rs` was restored to HEAD at 16:41:19
(mtime newer than the working 13:22:24-built binary), so the gate now
rebuilds and fails:

    error[E0433]: could not find `glsl_backend` in `debashl`
        --> cli/src/cli_commands.rs:707:27   (and cli/src/lib.rs:973:35)
    error[E0425]: cannot find function `strip_cfor` in module `debashl::shir_passes`
        --> cli/src/cli_commands.rs:705:27
        --> cli/src/lib.rs:940:35, 971:35, 996:35, 1021:35
    error: could not compile `debashcl` (lib) due to 7 previous errors

The py-sh-go frontend itself is healthy: `make build` passes, and the
emitted A1 shIR JSON is accepted by the existing binary
(`--shir-in-estree` exit 0). Only the oracle rebuild is blocked.

## MINIMAL-CORE-CHANGE
Verified in an isolated copy of the tree (`cargo check --bin debashc`
→ exit 0, after applying exactly these two edits):

1. `src/lib.rs` — after line 31 `pub mod zig_backend;`:
   ```rust
   pub mod glsl_backend;
   ```
2. `src/shir_passes/mod.rs` — after `pub mod restructure;`:
   ```rust
   pub mod strip;
   pub use strip::strip_cfor;
   ```
   NOTE: the plain `pub mod strip;` alone is NOT enough — the CLI calls
   `debashl::shir_passes::strip_cfor`, so the `pub use` re-export is
   required (rustc's suggestion: `use debashl::shir_passes::strip::strip_cfor;`).

Untracked WIP files involved (all owned by the estree worker):
`src/glsl_backend.rs`, `src/shir_passes/strip.rs`,
`src/bin/{sh2glsl,glsl_dump,shir_dump,sh_render_check}.rs`,
`examples/probe_{ir,lift}.rs`, plus the uncommitted `cli/src/{lib.rs,
cli_commands.rs}` edits. If the GLSL work is not ready to land, an equally
valid resolution is to stash/revert all of it so the committed tree builds
again.

## FAILING-CASE
Repro (no py-sh-go involvement needed):

    cd /home/llm/sh2loop/sh2perl && cargo build --bin debashc

fails with the 7 errors above. Gate-level repro:

    cd /home/llm/sh2loop/frontends/py-sh-go && make test

fails at the `$(DEBASHC)` rebuild step
(`make: *** [Makefile:40: .../target/debug/debashc] Error 101`) before
any frontend test runs.

## ADDENDUM 2026-08-12T17:06 (py-sh-go gate FAILED 2/3 at 17:02 — request still pending)

Still pending; the estree worker cannot process ANY request right now:
`main_loop_estree.pl` is stuck in
"No summary in fail-estree output (tree clean); sleeping and retrying"
forever, because its broken-WIP detection is blind to the actual WIP:

- `submodule_changed_paths()` (wide mode) only matches TRACKED changes
  under `^src/` — the WIP's tracked modifications are `cli/src/lib.rs`,
  `cli/src/cli_commands.rs`, `README.md` → invisible.
- UNTRACKED entries (`??`) are skipped by design — and the WIP is mostly
  untracked: `src/glsl_backend.rs`, `src/shir_passes/strip.rs`,
  `src/bin/{sh2glsl,glsl_dump,shir_dump,sh_render_check}.rs`,
  `docs/backend-glsl.md` → invisible.

So the "stash broken WIP and retry" branch never fires, the loop sleeps
30s per iteration, and the core-request mediation round (the only path
that would implement this request) is never reached: it runs only after
`fail-estree` produces a summary, and `fail-estree`'s `cargo build
--bin debashc` fails with the 7 errors above.

Unblock options (pick one, in order of preference):

1. Stash/revert the WIP by hand so the committed tree builds:
   `git -C sh2perl stash push -u -m glsl-wip -- src/ cli/ README.md`
   (`-u` makes the pathspec cover the untracked WIP files; plain
   pathspec stash on untracked files fails). Then the loop resumes
   normally and can implement this request's MINIMAL-CORE-CHANGE (or
   drop the request if the GLSL work is abandoned).
2. Fix the detection in `main_loop_estree.pl`: in wide mode also match
   tracked changes under `cli/`, and include untracked `src/` files in
   the stash (e.g. `git stash push -u -- src/ cli/ ...`), so the
   existing stash-and-retry branch fires on this state.
3. Implement the MINIMAL-CORE-CHANGE above (wire `glsl_backend` +
   `strip` into the lib) — verified `cargo check --bin debashc` exit 0.

Meanwhile the py-sh-go gate no longer hard-fails on the broken oracle
build: `frontends/py-sh-go/Makefile` now falls back to the existing
`target/debug/debashc` (last known-good build of the checked-out core;
the A1 contract files `shir_json.rs`/`shir_json_in.rs` have not changed
since that build, so `--shir-in-estree` ingress checks remain valid) and
re-arms the rebuild whenever a core source changes. The frontend itself
is healthy: all testdata emits are accepted by the existing binary.

## OUTCOME: implemented: the GLSL WIP landed (f5d761f: src/glsl_backend.rs + src/shir_passes/strip.rs + src/bin/* + the cli wiring) — `cargo build --bin debashc` compiles and the py-sh-go oracle rebuild is unblocked; no corpus regression (ESTree 521/521).
