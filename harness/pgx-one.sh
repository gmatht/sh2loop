#!/usr/bin/env bash
# pgx-one.sh — run examples through the REAL ./fail verdict, cheaply, one at a time.
#
# WHY. The canonical gate (`./fail`, run_perl_generator_worker.sh line 29) takes
# `timeout 500` over 557 examples with 6 parallel workers. Fixing a generator
# bug means rebuild-then-measure, and a full pass is the only way to prove the
# count dropped — so the loop is minutes per attempt. This script reproduces the
# SAME verdict for a subset so the edit/measure loop is seconds, and it is where
# the two paths are kept honest: the render target, the `perl -c` gate, the
# `do $__f` runner convention and the eq_exit==bash_rc contract below are copied
# from ./fail rather than guessed.
#
# THE TARGET IS NOT OBVIOUS. `shir_render --target=perl` renders the shIR
# intermediate; the product path ./fail gates is `file.sh -> perl text` straight
# through otranspilerl-cli. Those agree only if the CLI's perl path is the same
# code, so this script deliberately drives the CLI (`--target pl`, the spelling
# the previous revision of this file used) and a mismatch found here is a
# mismatch ./fail will report. Verifying that equivalence is the one thing this
# script does NOT assume — see `perl_target_differs_from_shir_render` in the
# notes at the bottom of this file.
#
# Usage:
#   harness/pgx-one.sh 0??_                 # every example matching a glob
#   harness/pgx-one.sh heredoc-unclosed.sh  # one named example
#   PGX_KEEP=1 harness/pgx-one.sh foo.sh    # keep the generated .pl, print its dir
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OTRANS="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
KS="$ROOT/harness/kill-session.sh"
[ -x "$OTRANS" ] || { echo "missing: $OTRANS" >&2; exit 1; }

pat="${1:-}"
corpus=$(ls "$ROOT"/sh2perl/examples/*.sh "$ROOT"/sh2perl/frontends/*/testdata/*.sh 2>/dev/null)
# An argument is an exact basename (`heredoc-unclosed.sh`) or a glob that
# GLOBS THE WHOLE BASENAME (`0???_*`). Matching is done with `case`, never with
# grep: `?` and `*` are regex quantifiers applied to the character BEFORE them,
# so the obvious spelling `grep -E "/$pat$"` reads `0??_` as "zero, then up to
# two of anything", and with the `$` anchor it matches nothing. That failure is
# invisible — grep exits 1, the script prints "no example matched", and the
# caller concludes there is no work to do. The glob must also be anchored at the
# FRONT: an unanchored `*heredoc*` would also select `subshell-heredoc-close`.
sel=""
if [ -n "$pat" ]; then
  for f in $corpus; do
    case "$(basename "$f")" in
      $pat) sel="$sel
$f" ;;
    esac
  done
fi
[ -n "$sel" ] || { echo "no example matched: $pat" >&2; exit 1; }

for f in $sel; do
  name=$(basename "$f")
  d=$(mktemp -d /tmp/pgx-XXXXXX)
  KEEP=${PGX_KEEP:-0}
  [ "$KEEP" = 1 ] || trap 'rm -rf "$d"' EXIT

  OTRANSPILER_ROOT="$ROOT" "$OTRANS" --target pl "$f" >"$d/gen.pl" 2>"$d/gen.err"
  grc=$?
  if [ "$grc" != 0 ] || [ ! -s "$d/gen.pl" ]; then
    echo "FAIL(render) $name"
    command grep -m3 . "$d/gen.err" 2>/dev/null | sed 's/^/      /'
    continue
  fi

  # ./fail discards a file whose emitted Perl does not compile. Reproduce that,
  # because "compiles but is wrong" and "does not compile" are different bugs
  # with different fixes, and folding the latter into a mismatch hides it.
  if ! perl -c "$d/gen.pl" >/dev/null 2>&1; then
    echo "FAIL(syntax) $name"
    perl -c "$d/gen.pl" 2>&1 | command grep -m3 . | sed 's/^/      /'
    [ "$KEEP" = 1 ] && echo "GEN: $d/gen.pl"
    continue
  fi

  (cd "$d" && "$KS" timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $__f=shift @ARGV; do $__f' "$f" "$d/gen.pl") >"$d/perl.out" 2>"$d/perl.err"
  pe=$?
  (cd "$d" && "$KS" timeout 20 bash "$f") >"$d/bash.out" 2>/dev/null
  be=$?

  if [ "$pe" = 124 ] || [ "$be" = 124 ]; then
    echo "TIMEOUT $name (eq=$pe bash=$be)"
  elif [ "$be" != "$pe" ]; then
    echo "FAIL(exit) $name  bash=$be perl=$pe"
    command grep -m3 . "$d/perl.err" 2>/dev/null | sed 's/^/      /'
  elif ! cmp -s "$d/perl.out" "$d/bash.out"; then
    echo "FAIL(stdout) $name"
    diff <(cat -A "$d/bash.out") <(cat -A "$d/perl.out") | head -12 | sed 's/^/      /'
  else
    echo "PASS $name"
  fi
  [ -s "$d/perl.err" ] && { echo "      --- perl stderr ---"; head -3 "$d/perl.err" | sed 's/^/      /'; }
  [ "$KEEP" = 1 ] && echo "GEN: $d/gen.pl"
  KEEP=0
  trap 'rm -rf "$d"' EXIT
done
exit 0