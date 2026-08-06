# otranspiler — the unified user-facing interface

One command over the frontend + backend fleet. Extension-driven
source/target dispatch, `-` for stdout, the neutral A1 (`.shir`) as a
first-class format in both directions, shell as the default source.

```
otranspiler <input> [<output>] [flags]
  input  file.{py,c,pl,sh,zsh,fish,go,shir}   (no ext = sh; - = A1 from stdin)
  output {-,file}.{c,js,pl,shir}              (no ext = js; - = stdout)
  --run        JS target: execute via the estree runner
  --shir       output the raw A1 contract
  --source-lang L / --target L   force the language (a .sh could be zsh)
```

Currently wired targets: `.js` (estree), `.pl` (perl), `.c` (shir_to_c),
`.shir` (the A1 contract). The other worktree renderers (go/rust/zig/
java/python/sh) exist but their `--shir-in-<lang>` ingress flags are not
connected — a clear error, not a silent fallback.

Dogfooding: `otranspiler otranspiler/main.go -` (Go -> JS self-transpile)
currently refuses — the go-sh frontend's subset stops at `bytes`/os/exec.
Self-hosting is the go-sh frontend's growth target.
