#!/usr/bin/env bash
# Regression check for the RUST NATIVE-ORACLE toolchain resolution in
# harness/frontend-stdout.sh (the rust-frontend's executed-stdout gate).
#
# THE DEFECT (2026-10-26). RUSTUP_HOME=/usr/local/rustup holds exactly one
# toolchain (1.90) and NO settings.toml, so there is no `default_toolchain`
# at all. rustup can then only resolve a version from a rust-toolchain.toml
# in the CWD's ANCESTRY — and the native rust arm compiles in `mktemp -d`
# under /tmp, i.e. ALWAYS outside the workspace, precisely to get per-run
# isolation. Result: every rust example's native side came back EMPTY while
# the transpiled side was CORRECT (65/65 DIFF), which the fleet reads as
# "the rust-frontend is failing to build" and is not: nothing was wrong
# with the frontend.
#
# Two halves, because either alone is a test that cannot fail:
#   1. STRUCTURAL — the native arm must not invoke bare `rustc`; it resolves
#      the channel the workspace pins (rust-toolchain.toml) and runs it
#      through `rustup run`, which ignores the scratch CWD.
#   2. BEHAVIOURAL — under a `rustc` shim on PATH that fails EXACTLY like
#      the no-default-toolchain rustup shim, the gate still compares against
#      a REAL native compiler (its example passes). The bare-`rustc` shape
#      derived from the SAME script must NOT pass: that proves the pin
#      bites rather than merely describing the code.
#
# A missing rustup skips the test (exit 0): the defect cannot exist there —
# a plain rustc resolves from any CWD — and asserting the rustup shape on
# such a box would fail for a reason that is not a regression.
set -uo pipefail
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
FE="$ROOT/frontends/rust-frontend"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
GATE="$ROOT/harness/frontend-stdout.sh"
rc=0

# --- preconditions ------------------------------------------------------
if ! command -v rustup >/dev/null 2>&1; then
  echo "SKIP: no rustup on PATH — a bare rustc resolves from any CWD, so the"
  echo "      scratch-CWD toolchain defect cannot occur on this box."
  exit 0
fi
tc=$(awk -F'"' '/^[[:space:]]*channel[[:space:]]*=/ {print $2; exit}' \
      "$ROOT/rust-toolchain.toml" 2>/dev/null || true)
if [ -z "$tc" ] || ! rustup run "$tc" rustc --version >/dev/null 2>&1; then
  echo "SKIP: the workspace pin (rust-toolchain.toml channel='${tc:-}') does not"
  echo "      resolve via rustup here; nothing for this check to pin."
  exit 0
fi
if [ ! -x "$FE/target/debug/rust-frontend" ]; then
  ( cd "$FE" && cargo build --offline ) || {
    echo "FAIL: cannot build rust-frontend (needed to run its example)"; exit 1; }
fi
if [ ! -x "$CLI" ]; then
  ( cd "$ROOT/otranspilerl" && cargo build --bin otranspilerl-cli ) || {
    echo "FAIL: cannot build otranspilerl-cli (the A1->ESTree oracle)"; exit 1; }
fi

# --- half 1: structural -------------------------------------------------
# Bare `rustc` in the native rust arm is the defect itself, whatever the box
# currently resolves to.
if command grep -q 'cd "$tmp" && timeout 60 rustc main.rs' "$GATE"; then
  echo "FAIL: the native rust arm still invokes bare \`rustc\` in the scratch"
  echo "      dir — rustup cannot pick a toolchain outside the workspace."
  rc=1
else
  echo "ok: native rust arm does not invoke bare \`rustc\`"
fi
if ! command grep -q 'rustc_cmd=(rustup run "\$rust_tc" rustc)' "$GATE"; then
  echo "FAIL: no rustup-run toolchain resolution derived from rust-toolchain.toml."
  rc=1
else
  echo "ok: rustc_cmd resolves the workspace-pinned channel via \`rustup run\`"
fi

# --- half 1b: the SAME defect at its second site -------------------------
# bat-triage-repro.sh runs every case in `mktemp -d /tmp/batrepro…` — outside
# the workspace, exactly like the gate's native arm — so its rust arm needs
# the identical resolution. Proved live 2026-10-26: a bare `rustc` there
# exits 1 and the arm returns EMPTY, which the repro reports as a stdout
# mismatch instead of a dead oracle.
BATREPRO="$ROOT/harness/bat-triage-repro.sh"
if command grep -q 'cd "\$wd" && rustc -A warnings' "$BATREPRO"; then
  echo "FAIL: bat-triage-repro.sh's rust arm still invokes bare \`rustc\` in a"
  echo "      /tmp scratch dir — every case silently yields empty stdout."
  rc=1
elif ! command grep -q 'rustc_cmd=(rustup run' "$BATREPRO"; then
  echo "FAIL: bat-triage-repro.sh has no rustup-run toolchain resolution."
  rc=1
else
  echo "ok: bat-triage-repro.sh rust arm resolves its toolchain too"
fi
# Behavioural half: the box cannot resolve a bare rustc in a scratch dir (the
# precondition above only proves the PIN resolves). When that is so, a known
# example must still come back OK — pre-fix it came back as a mismatch.
bare_broken=0
scratch=$(mktemp -d)
if ! ( cd "$scratch" && rustc --version ) >/dev/null 2>&1; then bare_broken=1; fi
rm -rf "$scratch"
if [ "$bare_broken" -eq 1 ] && [ -x "$BATREPRO" ]; then
  batout=$(timeout 300 bash "$BATREPRO" rust t02_set.bat 2>/dev/null | tail -1)
  case "$batout" in
    *OK*) echo "ok: bat-triage-repro rust case compares against a real compiler ($batout)" ;;
    *)    echo "FAIL: bat-triage-repro rust case got no oracle: ${batout:-<no verdict>}"
          rc=1 ;;
  esac
else
  echo "ok: bare \`rustc\` resolves here, so the bat-repro defect cannot occur"
fi

# --- half 2: behavioural ------------------------------------------------
TMP=$(mktemp -d) || exit 1
# frontend-stdout.sh appends one verdict row per basename to the TRACKED
# .frontend_gate.tsv cache (the GUI's per-example colours). Drop this run's
# own rows on exit so a repeated check leaves the file byte-stable instead
# of growing three rows per run. Only this check writes these names; a
# concurrent gate's appends are for real testdata names and survive.
cleanup() {
  rm -rf "$TMP"
  rm -f "$ROOT/harness/.frontend-stdout-prefix.$$.sh"
  python3 - "$ROOT/.frontend_gate.tsv" <<'PY' 2>/dev/null || true
import sys
p = sys.argv[1]
with open(p, encoding="utf-8", errors="replace") as f:
    lines = f.readlines()
keep = [l for l in lines if "zz_rf_toolchain" not in l]
if len(keep) != len(lines):
    with open(p, "w", encoding="utf-8") as f:
        f.writelines(keep)
PY
}
trap cleanup EXIT

# A `rustc` shim that fails the way an unpinned rustup shim fails. Names are
# deliberately not real testdata files: frontend-stdout.sh records a verdict
# row per basename, and a real name would repaint that example's GUI colour
# with this scratch run's verdict.
mkdir -p "$TMP/shim" "$TMP/td"
cat > "$TMP/shim/rustc" <<'SHIM'
#!/bin/sh
echo "error: rustup could not choose a version of rustc to run, because one wasn't specified explicitly, and no default is configured." >&2
exit 1
SHIM
chmod +x "$TMP/shim/rustc"

printf 'fn main() {\n    println!("hello rust");\n}\n' > "$TMP/td/zz_rf_toolchain_ok.rs"
# Padding so the whole-phase transient guard (which retries once, after 45s,
# only when EVERY test failed) cannot turn the negative control into a slow
# test. Refusal pins are skipped by name before any run — the exact path the
# real corpus's *_refuse.rs files take, so this adds no coverage claim.
: > "$TMP/td/zz_rf_toolchain_refuse_a.rs"
: > "$TMP/td/zz_rf_toolchain_refuse_b.rs"

run_gate() {  # <script> -> summary line(s) on stdout
  PATH="$TMP/shim:$PATH" bash "$1" rust "$FE/target/debug/rust-frontend" \
       "$TMP/td" "$CLI" 2>&1 | command grep '^--- frontend-stdout \[rust\]:'
}

post=$(run_gate "$GATE")
case "$post" in
  *"1/3 match, 0 FAIL, 2 SKIP"*)
    echo "ok: real toolchain used despite a dead \`rustc\` shim in the scratch dir ($post)" ;;
  *)
    echo "FAIL: the gate did not compare against a working native rustc — the"
    echo "      dead shim still decided the verdict: ${post:-<no summary>}"
    rc=1 ;;
esac

# The pre-fix shape: the ONLY difference is the compile invocation, so any
# change in the verdict is attributable to this fix and nothing else.
pre="$ROOT/harness/.frontend-stdout-prefix.$$.sh"
sed 's|timeout 60 "${rustc_cmd\[@\]}" main.rs|timeout 60 rustc main.rs|' "$GATE" > "$pre"
if cmp -s "$GATE" "$pre"; then
  echo "FAIL: could not derive the bare-\`rustc\` shape from the gate — this"
  echo "      check can no longer prove the defect is what it says it is."
  rc=1
else
  preout=$(run_gate "$pre")
  case "$preout" in
    *"1 FAIL"*)
      echo "ok: bare-\`rustc\` shape fails the same example ($preout)" ;;
    *)
      echo "FAIL: bare \`rustc\` still passed under the dead shim ($preout) —"
      echo "      the defect this check pins is not being exercised."
      rc=1 ;;
  esac
fi

[ "$rc" -eq 0 ] && echo "PASS: rust native oracle resolves its toolchain outside the workspace"
exit "$rc"
