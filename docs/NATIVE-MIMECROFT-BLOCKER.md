# Blocker: bash-O4 does not build (lost sh2perl revision)

Found 2026-09-26 while scoping a native bash-O4 MIMEcroft
(bash -> ShIR -> C -> tcc -> ELF, rendering to a Linux framebuffer).

## Symptom

`cargo build --offline` in `bash-o4/` fails: 11 errors, all
`otranspilerl` calling into `debashl` (the `sh2perl` submodule) for
symbols that do not exist:

    E0425 cannot find function `set_slots_enabled`   in debashl::shir
    E0425 cannot find function `set_split_sets`      in debashl::shir
    E0425 cannot find function `set_shaderize_enabled` in debashl::shir
    E0433 could not find `split_set` / `set_target`  in debashl::transforms

## Cause: a submodule revision that is not present

    sh2loop/  HEAD        1bf2e6cca  "sh2perl gitlink advances to PR #8 merge"
               gitlink     sh2perl -> dcd95cd0
    sh2perl/  checked out ee65be10   (2026-09-07)

`dcd95cd0` cannot be fetched. The configured remote is an SSH URL on
another host and is not reachable for that object:

    ai@10.42.0.1:/nvme/ai/sh2loop/sh2perl

After a fresh `git fetch`, searching **all refs** (including the new
`origin/main` at `ae0f3f26`) finds zero hits for `set_shaderize_enabled`
in any commit. So the needed revision is either never pushed, or lives
only on the NVMe host.

This is the same failure mode as the sh2runtime tcc fork
(`/root/src/tinycc-wasm`, see `recovery/RECOVERY.md`): a local-only
working state that was never pushed, plus a gitlink that points past
what any clone can see.

## What is NOT blocked

- **No `/dev/fb0` on this host** — only `/sys/class/graphics/fbcon`
  (text console). A *virtual* fb0 (mmap'd buffer dumped to PPM/PNG or a
  null sink) is therefore the only workable display target here, which
  is the right first design decision regardless.
- The fbdev software rasterizer and the MIMEcroft render-loop port do
  not depend on bash-O4. `bash-O4` is only the compiler front end
  (bash -> ShIR -> C); `tcc` + hand-written C reaches the same end
  state and is a valid substitute.
- MIMEcroft is already an active transpiler test case here, and is
  **known to miscompile**: see `INVESTIGATION-lifted-var-array-index.md`
  (set_treasure_pos records 1 of 10 artifacts) and
  `upstream-repros/README.md:23` (that repro: OPEN). Any native port
  inherits this until those passes are fixed.

## Unblocking options

1. Push `dcd95cd0` to the sh2perl remote from a host that has it.
2. Name a host/checkout holding the newer sh2perl.
3. Skip bash-O4: build native MIMEcroft against `tcc` + C directly.
   Recommended — the expensive work is the rasterizer and the port, and
   bash-O4 is replaceable.
4. Reconstruct the four sh2 pass-toggles. Semantics would be guesses
   and need review.
