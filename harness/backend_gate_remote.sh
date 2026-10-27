#!/bin/bash
# harness/backend_gate_remote.sh — run the CORPUS equivalence gate for a
# backend ON THE REMOTE BUILD BOX and bring the verdict back.
#
# WHY. `setup_backends.sh --backend-gate java` builds the core and then holds
# the fleet's single .gate.lock for the whole 654-file pass (20 min at best,
# 1-2 h under load), so on this box a backend gate can go an entire day
# without completing — and a renderer fix cannot be measured if the
# measurement never runs. The remote box (12 cores, idle, its own cargo
# cache) runs the same rules in ~5 minutes.
#
# THE RULES ARE THE GATE'S, NOT A REIMPLEMENTATION (see setup_backends.sh
# --backend-gate): render via the worktree `shir_render --target=<lang>`,
# STUB GATE on `TODO(unsupported)|sh2[A-Za-z_0-9]+\(`, `bash -n` skip for
# parse-error examples, then compile+run the render and compare STDOUT and
# EXIT CODE against `bash "$f"` — rc EQUALITY for the backends that joined
# that group (c perl sh rust zig python fish zsh), rc-0-on-both-sides for
# the rest (java today). Both sides run in an EMPTY scratch dir so a script
# that globs the CWD sees an identical file set.
#
#   harness/backend_gate_remote.sh <lang> [options]
#     --par N        parallel files (default 8; the box has 12 cores)
#     --prefix P     subset by filename prefix (repeatable)
#     --sync         rsync the live tree first (harness/remote-sync.sh)
#     --verbose      list every failing file with its class
#     --host HOST    default 192.168.1.117
# Exit 0 = gate GREEN, 1 = failures, 2 = harness/transport error.
set -uo pipefail

LANG_="${1:?usage: backend_gate_remote.sh <lang> [--par N] [--prefix P] [--sync] [--verbose]}"
shift
HOST=192.168.1.117
PAR=8
SYNC=0
CORE=0
VERBOSE=0
PREFIXES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --par) PAR="$2"; shift 2;;
    --prefix) PREFIXES+=("$2"); shift 2;;
    --sync) SYNC=1; shift;;
    --core) CORE=1; shift;;
    --verbose|-v) VERBOSE=1; shift;;
    --host) HOST="$2"; shift 2;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE=/root/sh2loop
SSHX=(ssh -o BatchMode=yes "$HOST")

case "$LANG_" in
  java)   EQ=javac;  RC_MODE=zero;;
  zig)    EQ=zig;    RC_MODE=equal;;
  *) echo "backend_gate_remote: unsupported lang $LANG_" >&2; exit 2;;
esac

if [ "$SYNC" = 1 ]; then
  "$ROOT/harness/remote-sync.sh" "$HOST" "$REMOTE" || { echo "sync FAILED" >&2; exit 2; }
  # INCREMENTAL: only the renderer crate is rebuilt. `cargo clean -p debashl`
  # (run once, by hand) removed the 900 MB per-worktree debashl artifacts,
  # so each re-render reuses the shared third-party deps and recompiles the
  # core + this backend in ~40 s. The core emitter is NOT rebuilt here: it
  # changes only when sh2perl/src changes, and the gate's shIR is the
  # local tree's contract either way (pass --core to force it).
  "${SSHX[@]}" "export PATH=/usr/local/cargo/bin:\$PATH RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo; cd $REMOTE
    $([ \"${CORE:-0}\" = 1 ] && echo 'cargo build --manifest-path otranspilerl/Cargo.toml --bin otranspilerl-cli 2>&1 | tail -1')
    cargo build --manifest-path sh2perl/backends/$LANG_/Cargo.toml --bin shir_render 2>&1 | command grep -E '^(error|    Finished)' -A3 | head -12" || { echo "remote build FAILED" >&2; exit 2; }
fi

# The remote worker script. It is written from HERE (single source), so the
# verdict cannot drift from what this file documents.
RW="$REMOTE/.remote_gate_$LANG_.sh"
"${SSHX[@]}" "cat > $RW" <<'REMOTE_EOF'
#!/bin/bash
# args: PAR LANG JAVAC_ARM PREFIXES...
PAR="$1"; L="$2"; RCMODE="$3"; shift 3
ROOT=/root/sh2loop; SUB=$ROOT/sh2perl
RENDERER=$SUB/backends/$L/target/debug/shir_render
OTRAN=$ROOT/otranspilerl/target/debug/otranspilerl-cli
KS=/usr/bin/timeout          # kill-session.sh is not needed: every run is
                             # bounded and runs in its own scratch dir
export SH2_UU_FFI=1
# the CLI locates the workspace from the SOURCE PATH; a bare run outside the
# tree cannot find the root (that is why the gate cd-s nowhere but exports it)
export OTRANSPILER_ROOT=$ROOT
export SH2_UU_LIB=$SUB/runtime/lib/libcoreutils_ffi.so
export SH2_UU_PIPELINE_LIB=$SUB/runtime/lib/libcoreutils_ffi_pipeline.so
export UU_FFI_MULTICALL=$SUB/runtime/lib/coreutils-ffi-multicall

# ZIG CACHE CEILING — this gate runs `zig run` per corpus file, so the
# REMOTE ~/.cache/zig is the one that grows. Prune it to the 8 GiB ceiling
# before the pass (harness/ is rsynced by remote-sync.sh, so the wrapper is
# present when --sync ran). Same contract as the local hooks: best-effort,
# always exits 0 — a maintenance step must never turn the gate red.
if [ "$L" = zig ] && [ -f "$ROOT/harness/zig-cache-prune.sh" ]; then
  bash "$ROOT/harness/zig-cache-prune.sh" || true
fi

one() {
  local f="$1" shir out s d wd eq_exit bash_rc t0 t1 t2 t3 t4
  # ZIG RESOLVES THE SOURCE PATH AGAINST THE CWD, NOT THE CACHING DIRECTORY
  # (`zig run sub/p.zig` from elsewhere dies with
  # `unable to load "p.zig": FileNotFound`), so the render must be written
  # into the scratch dir the run cd's to — writing it before the `cd` put it
  # in a DIFFERENT dir entirely and 21 files reported a phantom build
  # failure. `zigpath` is that dir; the java arm keeps `$wd` for its class
  # files and uses it directly (javac is happy with absolute paths).
  # UNIQUE per file: $RANDOM is re-seeded per `bash -c` child, so two
  # concurrent files drew the SAME $wd and overwrote each other's
  # Sh2Program.java — at --par 16 that produced 16 phantom "javac: class,
  # interface, enum, or record expected" failures. mktemp cannot collide.
  wd=$(mktemp -d /tmp/rg.XXXXXXXX)
  if ! shir=$("$OTRAN" --target shir "$f" 2>/dev/null); then echo "FAIL $f|emit|"; rmdir "$wd"; return; fi
  if [ -z "$shir" ]; then echo "FAIL $f|emit_empty|"; rmdir "$wd"; return; fi
  if ! bash -n "$f" 2>/dev/null; then echo "SKIP $f|parse|"; rmdir "$wd"; return; fi
  if ! out=$(printf '%s' "$shir" | "$RENDERER" --target="$L" - 2>/dev/null); then
    echo "FAIL $f|render|"; rmdir "$wd"; return
  fi
  s=$(printf '%s' "$out" | command grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  if [ "${s:-0}" -gt 0 ]; then
    d=$(printf '%s' "$out" | command grep -oE 'sh2[A-Za-z_0-9]+\(|TODO\(unsupported\)' | sort | uniq -c | sort -rn | head -2 | tr '\n' ' ')
    echo "FAIL $f|stub($s)|$d"; rmdir "$wd"; return
  fi
  case "$L" in
    java)
      printf '%s' "$out" > "$wd/Sh2Program.java"
      t1=$(date +%s%N)
      if ! javac -d "$wd" "$wd/Sh2Program.java" >"$wd/err" 2>&1; then
        d=$(command grep -E 'error:' "$wd/err" | head -1 | cut -c1-140)
        echo "FAIL $f|javac|$d"; rm -rf "$wd"; return
      fi
      t2=$(date +%s%N)
      ( cd "$wd" && exec timeout 15 java -Xshare:auto -XX:TieredStopAtLevel=1 -cp "$wd" Sh2Program > "$wd/out" 2>/dev/null ); eq_exit=$?
      t3=$(date +%s%N)
      echo "TIM $(( (t2-t1)/1000000 )) $(( (t3-t2)/1000000 )) $f" >> /tmp/gate_times.txt;;
    zig)
      # UU-FFI exactly as the gate's zig arm links it (see setup_backends.sh):
      # the renderer's in-process arm needs libcoreutils_ffi, `-lc` is
      # REQUIRED (a Rust cdylib does not initialise without libc and
      # uu_run segfaults), and zig spells rpath as a first-class flag.
      # WITHOUT these flags 21 files failed with "undefined symbol: uu_run" —
      # a HARNESS gap that reads exactly like a renderer bug.
      printf '%s' "$out" > "$wd/p.zig"
      ( cd "$wd" && exec timeout 30 zig run ./p.zig -lc \
          -L"$SUB/runtime/lib" -lcoreutils_ffi -rpath "$SUB/runtime/lib" \
          > "$wd/out" 2>"$wd/err" ); eq_exit=$?
      if [ "$eq_exit" = 124 ]; then
        tt1=$(date +%s%N)
        ( cd "$wd" && exec timeout 40 zig build-exe ./p.zig -lc -L"$SUB/runtime/lib" -lcoreutils_ffi -rpath "$SUB/runtime/lib" >/dev/null 2>&1 )
        tt2=$(date +%s%N)
        echo "TIMZ build=$(( (tt2-tt1)/1000000 ))ms $f" >> /tmp/gate_times.txt
      fi
      if [ -s "$wd/err" ] && [ "$eq_exit" != 0 ] && ! [ -s "$wd/out" ]; then
        d=$(command grep -E 'error:' "$wd/err" | head -1 | cut -c1-140)
        echo "FAIL $f|zigbuild|$d"; rm -rf "$wd"; return
      fi;;
  esac
  ( cd "$wd" && exec timeout 15 bash "$f" > "$wd/ref" 2>/dev/null ); bash_rc=$?
  if [ "$eq_exit" = 124 ] || [ "$bash_rc" = 124 ]; then
    echo "FAIL $f|timeout|java=$eq_exit bash=$bash_rc"; rm -rf "$wd"; return
  fi
  local ok=0
  if [ "$RCMODE" = equal ]; then
    [ "$eq_exit" = "$bash_rc" ] && diff -q "$wd/out" "$wd/ref" >/dev/null 2>&1 && ok=1
  else
    [ "$eq_exit" = 0 ] && [ "$bash_rc" = 0 ] && diff -q "$wd/out" "$wd/ref" >/dev/null 2>&1 && ok=1
  fi
  if [ "$ok" = 1 ]; then echo "PASS $f"; rm -rf "$wd"; return; fi
  d=$(diff "$wd/out" "$wd/ref" 2>/dev/null | head -4 | tr '\n' '~' | cut -c1-160)
  echo "FAIL $f|equiv(rc $eq_exit/$bash_rc)|$d"
  rm -rf "$wd"
}
export -f one
export L RENDERER OTRAN RCMODE
# ROOT/SUB are read INSIDE one() (the uu-ffi link paths and the renderer
# location); the function body runs in a `bash -c` child, which sees ONLY
# exported names. Without SUB the zig arm linked
# `-L"/runtime/lib" -lcoreutils_ffi` and every file died with
# `unable to find dynamic system library "coreutils_ffi"`.
export ROOT SUB

files=()
for f in "$SUB"/examples/*.sh "$SUB"/frontends/*/testdata/*.sh; do
  [ -f "$f" ] || continue
  if [ "$#" -eq 0 ]; then files+=("$f"); else
    b=$(basename "$f")
    for p in "$@"; do case "$b" in "$p"*) files+=("$f"); break;; esac; done
  fi
done
log=/tmp/remote_gate_$L.$$.log
printf '%s\n' "${files[@]}" | xargs -P "$PAR" -I{} bash -c 'one "$@"' _ {} > "$log" 2>/dev/null
echo "== [$L] remote gate: $(command grep -c '^PASS' "$log" || true) pass / $(command grep -c '^FAIL' "$log" || true) fail / $(command grep -c '^SKIP' "$log" || true) skip (of $(wc -l < "$log"))"
echo "-- classes:"
command grep '^FAIL' "$log" | cut -d'|' -f2 | sed 's/(.*//; s/[0-9]\+//g' | sort | uniq -c | sort -rn
echo "LOG $log"
REMOTE_EOF

"${SSHX[@]}" "chmod +x $RW && $RW $PAR $LANG_ $RC_MODE ${PREFIXES[*]:-}" > /tmp/remote_gate_$LANG_.out 2>&1
rc=$?
cat /tmp/remote_gate_$LANG_.out
if [ "$VERBOSE" = 1 ]; then
  LOG=$(command grep '^LOG ' /tmp/remote_gate_$LANG_.out | awk '{print $2}')
  [ -n "$LOG" ] && "${SSHX[@]}" "command grep '^FAIL' $LOG | sed 's|/root/sh2loop/sh2perl/||'"
fi
[ $rc -eq 0 ] || exit 2
