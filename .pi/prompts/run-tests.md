---
description: Run the sh2loop corpus gate and summarize results
---

Run the corpus gate and summarize:

- `./fail` — Perl baseline (prefix filter: `./fail <prefix>`).
- If `./fail-estree` exists, run it too and report both verdicts.
- Report: passed/failed counts, first N failures with reasons, any regressions
  vs the last recorded counts (PLAN.md §0), and whether a fix or a blessed-fail
  entry is needed.
