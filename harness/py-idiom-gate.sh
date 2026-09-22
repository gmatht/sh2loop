#!/usr/bin/env bash
# py-frontend RUST-IDIOM gate.
#
# The bash corpus (./fail) never exercises the py-sh-go frontend, so a shape
# like t27's `thread_local` + `.clone()` can regress (or stay unfixed)
# unnoticed. This gate renders selected py programs to Rust and asserts the
# LOCAL-VARIABLE shapes a human would write.
#
# Usage: harness/py-idiom-gate.sh [otranspilerl-cli]
#
# Each case is (program, must-absent regex, must-present regex). A case fails
# if the first matches or the second does not.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLI=${1:-${SH2_CLI:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}}
DIR=$ROOT/sh2perl/frontends/py-sh-go/testdata

if [ ! -x "$CLI" ]; then
    echo "py-idiom-gate: no otranspilerl-cli at $CLI" >&2
    echo "  build: cargo build --bin otranspilerl-cli  (in otranspilerl/)" >&2
    exit 2
fi

pass=0
fail=0
# a case's first field is the program (the .py under testdata/), which must
# also EXIST — a renamed test should fail loudly, not silently pass.
check() {
    local prog=$1 absent=$2 present=$3 out
    if [ ! -f "$DIR/$prog.py" ]; then
        echo "FAIL $prog: no such testdata/$prog.py"
        fail=$((fail + 1))
        return
    fi
    out=$("$CLI" "$DIR/$prog.py" - --target rs 2>&1)
    if [ -z "$out" ]; then
        echo "FAIL $prog: no Rust output"
        fail=$((fail + 1))
        return
    fi
    if [ -n "$absent" ] && printf '%s' "$out" | grep -qE "$absent"; then
        echo "FAIL $prog: non-idiomatic (matched /$absent/):"
        printf '%s\n' "$out" | grep -E "$absent" | head -2 | sed 's/^/    /'
        fail=$((fail + 1))
        return
    fi
    if [ -n "$present" ] && ! printf '%s' "$out" | grep -qE "$present"; then
        echo "FAIL $prog: expected /$present/, got:"
        printf '%s\n' "$out" | sed -n '/fn main/,$p' | head -8 | sed 's/^/    /'
        fail=$((fail + 1))
        return
    fi
    pass=$((pass + 1))
}

# ── a string local read by a test is a native `let`, not a thread-local ──
# t27: `x = ""` then `if not x:` — the frontend lowers the test to
# `test("-z \"$x\"")`, whose `$x` lives in the arg TEXT. If the borrow walk
# misses that read the verdict withholds: thread_local + store + clone.
check t27_not_expr 'thread_local' 'let x = ""'
check t27_not_expr '\.borrow\(\)\.clone\(\)' 'x\.is_empty\(\)'

# ── a constant-RHS compare needs no glob helper or String allocation ──
check t26_str_cmp 'format!\(""|__sh_glob_like|__sh_fnmatch' 'if "a" == "a"'

# ── a py variable is a plain local, never a thread-local ──
check t25_num_cmp 'thread_local' ''
check t24_str_cat 'thread_local' ''

# ── boolean `and`/`or`: locals, no status wrappers, no allocation ──
# t28's `a = "a"; b = "b"; if a == "a" and b == "b":` — the RHS literal is a
# comparison VALUE, so it must not be mistaken for a read of `a` (that would
# block the local verdict), each `&&` operand's dead `{ let __b = … }`
# status wrapper must go, and a borrowed read compares to a bare literal.
check t28_and_or 'thread_local' 'let a = "a"'
check t28_and_or 'let __b' 'a == "a" && b == "b"'
check t28_and_or '\.to_string\(\)' ''
# a status-free source strips every trailing `__SH_RC.store(0, …)`; the
# emptied line is a REMOVED statement, not a blank separator (the t28 shape
# used to render `let a = …;\n\nlet b = …;\n\nif …`)
check t28_and_or '^$' 'fn main'

echo "py-idiom-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
