# verif/ — machine-checked claims about the C backend

Two kinds of claim live here, and they are NOT the same kind of claim.

## The verdict/UB sessions (`ROOT`, session `"Sh2"`)

`P1_Narrowing`, `P2_Checked`, `P3_Capacity`, `P3_Buffer` — the claims
C_UB_PROOF.md sets out (width narrowing, the checked-overflow tier, buffer
bounds). Build:

    isabelle build -D verif "Sh2"

`quick_and_dirty = false` is pinned in the ROOT, so `sorry` is rejected rather
than hidden.

## The use-after-free obligation (`ROOT.memsafety`, theory `MemorySafety.thy`)

The question "can Isabelle prove the C backend produces no use-after-free?"
has a reachable per-program form and an unreachable end-to-end one
(README in C_UB_PROOF.md §3 explains the split: the runtime, frontend and
stubs are unproved, so an end-to-end theorem would quantify over them).

`MemorySafety.thy` states the per-program obligation about an abstract
memory (`Alloc`/`Free`/`Load`/`Store`) and proves the shape of it:
`uaf_free_disjoint` ("a safe trace never accesses a block after a release
that was not followed by a fresh allocation") and
`at_most_once_wf` (the renderer's dedup gives half of well-formedness).

STATUS: **not green, not in the default build.** Two lemmas do not close
with bounded automation — the unfold of `safe_for_def` (a `\<nexists>` over a
list split) diverges `meson`/`simp` — so the session is parked as
`ROOT.memsafety` and the gate reports it `FAILED` rather than skipping it.
Renaming it to `ROOT` is the "done" switch.

What it is NOT: a proof that the C backend discharges the obligation. That
needs a per-program generator (emit the renderer's free sites as an `act
list`, discharge `well_formed` and `safe_for` per block), which does not
exist. `harness/c-memory-safety.sh` is the measurement that stands in for it
today (ASan over every C render, with positive controls).
