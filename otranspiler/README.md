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

Wired targets: `.js` (estree), `.pl` (perl), `.c`, `.go`, `.py`, `.sh`,
`.java`, `.rs`, `.zig` (the worktree `--shir-in-<lang>` ingress flags),
and `.shir` (the A1 contract). sh/java's v1 renderers refuse constructs
outside their subset (e.g. the seq-range Range node) with a clear error —
refuse > guess, surfaced cleanly by otranspiler (never the CLI's
shell-command fallback).

Source frontends build themselves on first use: every frontend
(`frontends/{go,py,c,perl,zsh,fish}-sh-go`) is a plain Go program, so a
missing binary (fresh checkout) just triggers a `go build` in its dir
before the dispatch — `GO` env var honored, else `go` from PATH. No
separate build step to remember.

Dogfooding: `otranspiler otranspiler/main.go -` (Go -> JS self-transpile)
currently refuses — the go-sh frontend's subset stops at `bytes`/os/exec.
Self-hosting is the go-sh frontend's growth target.
