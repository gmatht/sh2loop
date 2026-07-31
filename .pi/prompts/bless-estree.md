---
description: Curate the blessed-fail-estree allowlist (Stage B gate)
---

Curate `blessed-fail-estree.txt` (the Stage B gate allowlist):

- List tests currently failing the ESTree gate with their reasons.
- A test may be blessed only for a **known runtime limitation** (external tool
  missing from the command registry, process-semantics edge case) — never for a
  transpiler bug.
- Never bless a regression: verify the Perl backend still passes the test
  before blessing it.
