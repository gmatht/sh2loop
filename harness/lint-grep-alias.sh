#!/usr/bin/env bash
# lint-grep-alias.sh — the `grep` shadowing trap, enforced instead of
# documented.
#
# WHY: the workers' shell defines a `grep` function that forwards to
# ripgrep. `rg` rejects `-q`, `-i` and `-F`, so a bare `grep -q PATTERN`
# returns NON-ZERO FOR EVERY INPUT — including files that contain the
# pattern. It has already silently broken a test that could not fail, a
# printf, and a `fail-go` getVar guard in one session. A check that returns
# non-zero for everything reads exactly like a correct negative result.
#
# `command grep` bypasses the function. This lint fails when the gating
# surface (the scripts whose wrong answer is worse than no answer) uses a
# bare grep with a flag ripgrep does not take.
#
#   ./harness/lint-grep-alias.sh         gate surface
#   ./harness/lint-grep-alias.sh --all   every tracked *.sh / *.pl
#
# Exit 1 = offenders found, printed as file:line:text.
set -uo pipefail

ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 2

if [ "${1:-}" = "--all" ]; then
  mapfile -t FILES < <(git ls-files '*.sh' '*.pl' fail fail-coreutils fail-estree 2>/dev/null)
else
  # The gate surface + the tools whose job is to READ an answer. Legacy
  # harness/*.sh helpers are counted by --all; rewriting them mechanically is
  # a separate, reviewable change.
  mapfile -t FILES < <(
    {
      ls fail fail-coreutils fail-estree setup_backends.sh 2>/dev/null
      ls tests/coreutils/* 2>/dev/null | command grep -v '\.md$'
      ls harness/check_ast.pl harness/rust-warning-census.sh \
         harness/render-snapshot.sh harness/parked-work.sh \
         harness/core-requests-queue.pl 2>/dev/null
    } | command grep -v -e 'lint-grep-alias.sh' -e '\.md$'
  )
fi

[ "${#FILES[@]}" -gt 0 ] || { echo "lint-grep-alias: no files to scan"; exit 0; }

# A bare grep whose flag cluster contains `q`. ripgrep HAS -i and -F; it does
# not have -q, so `grep -q`, `grep -qi` and `grep -qF` are the broken ones.
# `command grep` is the fix, so those lines are not offenders.
# Skip comments (they describe the trap, they don't run) and `git ... grep`
# (that is git's builtin, not the shell function).
hits="$(
  command grep -nE '(^|[^A-Za-z0-9_/-])grep +-[A-Za-z]*q' "${FILES[@]}" 2>/dev/null \
  | command grep -v 'command grep' \
  | command grep -vE '^[^:]+:[0-9]+: *#'
)"

if [ -n "$hits" ]; then
  echo "lint-grep-alias: bare grep with a ripgrep-incompatible flag —"
  echo "  under the workers' shell these return non-zero for EVERY input."
  echo "  Use 'command grep' (or awk) instead:"
  echo
  printf '%s\n' "$hits"
  echo
  echo "lint-grep-alias: ${#FILES[@]} file(s) scanned, $(printf '%s\n' "$hits" | wc -l) offender line(s)."
  exit 1
fi

echo "lint-grep-alias: ${#FILES[@]} file(s) scanned, 0 offenders."
exit 0
