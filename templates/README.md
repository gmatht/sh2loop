# templates/ — the probe template library for translate_one_application.sh

One template per construct the miner can detect, in the source language:

    templates/<lang>/<construct>.<ext>   the minimal probe (one construct,
                                        hermetic, side-effect-free,
                                        deterministic — its stdout IS the
                                        oracle)
    templates/<lang>/<construct>.sig    a grep -E pattern that fires when
                                        the app uses the construct

The miner copies each fired template into .translate-work/probes/ (capped
at MAX_PROBES), deduped by name. Add a new construct by writing both files
(mirror an existing pair; sigs must be ERE-safe: literal `(`, `)`, `{`,
`}` use bracket classes `[(]` `[)]` `[{]` `[}]`; literal `|` is `\|`).

Seeded: sh (19 constructs — the canonical ladder: for seq/list, while,
until, if/elif, case-glob, arrays (lit/index/append), param
default/subst/prefix, cmdsub, pipe, func, test, brace, arith, heredoc)
and zsh (5). py/pl/go/fish have no seeds yet — the constructs map
per-language (the ladder is the same FEATURES, written in each source
language); add them to give those frontends mined work.
