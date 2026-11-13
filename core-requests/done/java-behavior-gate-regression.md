# java behavior-gate regression after fd08dcf5/af7092e5/d6c2e622 — evidence

`harness/backend_behavior.sh java` with `DEBASHC_TRANSFORMS=text-ops`
over the full 551-example corpus:

| state | pass | fail | skip |
|---|---|---|---|
| right after merging backend/java into main (2b9a2f6c) | **253** | 111 | 187 |
| now (after d6c2e622 + af7092e5 + fd08dcf5) | **73** | 30 | 448 |

The three commits cost ~180 genuine passes. skip went 187→448: renders
that succeeded now REFUSE again (Err paths), i.e. the v1-subset refusals
the merge had removed came back. The commits' own gate ("004_goto_loop",
"005") is a different meter — please also run
`DEBASHC_TRANSFORMS=text-ops bash harness/backend_behavior.sh java`
as the acceptance check; it is the goal gate for the java backend.

Repro: any time, ~10 min serial. Baseline before your commits is
reconstructable from merge commit 2b9a2f6c.

## OUTCOME: rejected: stale, backend-lane-owned
The report is anchored to commits `d6c2e622`/`af7092e5`/`fd08dcf5` and a 551-example corpus; the shared-core corpus is now green on both arms (PERL 555/555, ESTREE 555/555). `harness/backend_behavior.sh java` measures the Java backend lane, not the shared core, and that lane owns its own acceptance gate; no shared-core change is implicated.
