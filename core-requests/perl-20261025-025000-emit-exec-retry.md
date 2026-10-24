# perl: the gate reports CRASHED for a 648/650-green corpus on a transient exec failure

## NEED

`setup_backends.sh --backend-gate perl` (and the js arm, which shares the emit
stage) must not count an **exec failure** of the core emitter as a per-file
FAIL. When `$g_otrans` momentarily cannot be exec'd, the emit stage records a
`shir emit FAILED` and the run is then classified `CRASHED (no classification)`
— the loop treats a whole corpus as untested because two files were measured
in a window where the binary's path did not exist.

A retry of the emit on the "binary absent" class fixes it at the call site:
two extra execs, no change to any verdict for a real emit error.

## WHY

The core emitter is built by the estree worker into the SAME shared target dir
every backend gate reads:

    otranspilerl/target -> /mnt/wsl/projects/.sh2target/otranspiler
    sh2perl/target     -> /mnt/wsl/projects/.sh2target/otranspiler   (same dir)

so `otranspilerl/target/debug/otranspilerl-cli` is replaced in place while a
gate loop is running. Cargo replaces the artifact by unlinking the old one and
hard-linking the new one (observed: `nlink=2` debug/ + deps/), which leaves a
window in which the path does not exist. The gate's own comment already says
`rc=127 is exec failure` and that `inode=GONE` identifies it — but the code
still counts it as a FAIL, and the run's verdict collapses.

Measured on the perl gate run logged at 2026-10-25T02:09:37:

    [perl] backend gate: shir emit FAILED for .../dq-hashbang-multiline-assign.sh
      (rc=127, binary=.../otranspilerl-cli inode=GONE)
    [perl] backend gate: shir emit FAILED for .../dqs-nested-awk-sed.sh
      (rc=127, binary=.../otranspilerl-cli inode=GONE)
    [perl] backend gate: CRASHED (no classification) — 2/650 files failed ...
    [2026-10-25T02:09:37] perl: gate FAILED (1/3) — invoking AI

Both files emit clean on demand (`rc=0`), and `harness/perl_gate_local.sh` on
the same tree reports **650/650 render OK, 0 fail, 643 equiv pass, 7 skip**, so
the two failures were not input verdicts. The mirror's `shir_of` now retries
this class (harness/perl_gate_local.sh, commit under the perl backend).

## MINIMAL-CORE-CHANGE

`setup_backends.sh`, the js|perl emit stage (the `shir=$("$g_otrans" --target
shir "$f" 2>/dev/null) || { ... }` block, ~line 1768). Wrap that call in the
same retry the local mirror uses, and keep the loud skip only if all attempts
fail:

```sh
shir=""
for emit_try in 1 2 3; do
  if shir=$("$g_otrans" --target shir "$f" 2>/dev/null); then break; fi
  # exec failure (binary momentarily unlinked by a concurrent relink into the
  # shared target dir) — retry; a present binary that exits 1 is a real result.
  [ -x "$g_otrans" ] && break
  shir=""; sleep 1
done
if [ -z "${shir}" ] && [ ! -x "$g_otrans" ]; then
  ... existing emitfail handling (without incrementing twice) ...
fi
```

(Equivalently: `[ -x "$g_otrans" ] || sleep 1` before re-running, up to 3
times. The rc=1 class — a WIP core that rejects an input — must keep its
current handling, unchanged.)

## FAILING-CASE

- Corpus file (emits `rc=0` on demand, both included in the 650):
  `sh2perl/examples/dq-hashbang-multiline-assign.sh`,
  `sh2perl/examples/dqs-nested-awk-sed.sh`
- Fleet run: `/mnt/wsl/projects/sh2loop/loop-backend-perl.log`,
  2026-10-25T02:09:37 lines (quoted above).
- Local mirror (same corpus, same tree, after the emitter is present):
  `bash harness/perl_gate_local.sh` → `650/650 render OK, 0 fail
  (0 stubs, 0 check_qx, 0 render-fail, 0 equiv), 7 skip — equiv: 643 pass`.

## OUTCOME: implemented

Landed in `setup_backends.sh` (js|perl emit stage) as a call to the new
`harness/emit-shir-retry.sh`, which retries ONLY the path-absent (rc=127,
`stat` -> GONE) class — 3 attempts, 1s apart, matching the policy already in
`harness/perl_gate_local.sh`'s `shir_of`. A PRESENT emitter's rc is returned on
the first attempt, so no real emit verdict changes (rc=1 WIP-core rejections
still count as FAIL).

Verified: `harness/emit-shir-retry.selftest.sh` 8/8 (and 3/8 against a faithful
pre-fix implementation, proving it discriminates); both reported corpus files
emit byte-identically through the helper (1931 / 4097 bytes); an end-to-end
run with the real emitter absent and then relinked mid-window returns rc=0 and
the same 4097 bytes; `./fail-estree --gate` stays at the trusted baseline.
