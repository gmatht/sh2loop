# core-request: int-homed array stores string values via atoll (name table zeroed)

Filed by the `bash-o4` (fb0-raster) worker. Player-visible freeze:
after SPACE at the settings menu, the game wedged at
`loading block textures…` — post-menu `load_textures` drains up to
15 background texture jobs at ~12 s each (~180 s stall).

## Root cause (verified with minimal reproducers)

`tex_bg_jobs=(0 0 0 …)` (15 zeros) in `MIMEcroft_fb.sh` holds texture
NAMES (`tex_bg_submit` stores `$tbn_name`: stone, grass, …). The
all-numeric init literal is taken as int evidence, so the array homes
`long long[1024]` and every name store goes through `atoll` → 0.
`tex_bg_done` then polls `/tmp/mimecroft-bg-0.tsv`, which never lands,
and each job burns its 240 × 0.05 s poll budget.

Minimal A/B through the current driver (`bash-O4 --emit-c`):

| init | home | `jobs[0]=stone; jobs[1]=grass` at runtime |
|---|---|---|
| `(0 0 0 0 0)` | `long long[1024]`, stores via `atoll` | `job0=0 job1=0` (WRONG — bash prints the names) |
| `("" "" "" "" "")` | `char*[1024]`, stores via `strdup` | `job0=stone job1=grass` (matches bash, incl. `${#jobs[@]}`) |

## Workaround landed (game-side, no core change)

`bash-o4/MIMEcroft_fb.sh`: initializer is now 15 empty strings with a
comment explaining why zeros are load-bearing-wrong. Verified
end-to-end: SPACE → all 17 texture lines → `ready.` → game runs →
clean quit (was: wedged past timeout without printing even `stone…`);
`--demo` 121 frames, textured.

## Suspected analysis gap (for the core owner)

The init-literal int evidence is not re-validated against later string
stores: `demote_stringy_ints` (which re-validates other proposals)
does not catch this shape. A positional-sourced store (`tbn_name=$1`)
into an init-homed-int array silently zeroes. Other backends trusting
the same home will miscompile the same way — the repro above is
renderer-agnostic shell. Suggested rule: a store of a non-numeric
provenance (function arg, `$1`, string op result) into an int-homed
array should demote the home (or at minimum warn), the way string
observations already demote scalar homes.
