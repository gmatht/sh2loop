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

# ── a ternary binds ONCE: `y = "yes" if x > 0 else "no"` ──
# The frontends lower it to an `If` whose branches assign the same name. It is
# one definition, not two writes, so the name is a local (and borrowable), and
# the Rust keeps the expression form: `let y = if x > 0 { "yes" } else { "no" }`.
check t30_ternary 'thread_local' 'let y = if x > 0'
check t30_ternary '\.to_string\(\)' ''
check t30_ternary '__SHV_' ''

# ── an `elif` chain stays a chain ──
# The py lowering nests `elif` inside `else`; the shared else-if-flatten
# transform turns it back into `elsifs`, which every renderer emits as the
# chain form (Rust: `} else if c {`, not `} else { if c {`).
# (the absent-pattern needs no brace: `grep -E` treats `{` as a quantifier
# opener outside a group, so a literal brace would need escaping)
check t31_case_switch '^        if x == 2' 'else if x == 2'
check t31_case_switch 'thread_local' ''
# a NUMERIC ternary takes numeric arms (`a`, not the stringified arith wrap)
check t28_and_or 'thread_local' ''
# a status-free source strips every trailing `__SH_RC.store(0, …)`; the
# emptied line is a REMOVED statement, not a blank separator (the t28 shape
# used to render `let a = …;\n\nlet b = …;\n\nif …`)
check t28_and_or '^$' 'fn main'

# ── arithmetic literals take their type from the local's inferred type ──
# t29's `x += 1`: the Int local is inferred (not `: i64`), so the added
# literal needs no widening suffix (`x + 1`, not `x + 1i64`).
check t29_increment '1i64' 'let mut x = 1'

# ── a constant capture is the value, not an output-buffer block ──
# t33/t34: `subprocess.run(["echo", "hi"], capture_output=True).stdout.strip()`
# is one literal echo, so the capture folds to a string.
check t34_cmdsub '__SH_OUT|__cap|__sh_puts' 'let x = "hi";'
check t33_pipe '__SH_OUT|__cap|__sh_puts' 'let out = "hello";'

# ── a name-argument read makes the local borrowable ──
# t37/t38: the operand of `s[1:3]` / `len(s)` is a NAME string in the
# call (`param("slice", "s", …)`); recognising it as a read lets `s` bind
# as a `&str` instead of an owned String with a `.clone()` per use.
# The shell helpers `__sh_substr` / `__sh_len` are inlined as idiomatic
# `chars().skip(...).take(...)` and `chars().count() as i64`.
check t37_substring 'to_string\(\)|&s\.clone\(\)|__sh_substr' 'chars\(\).skip\(1\).take\(2\)'
check t38_strlen 'to_string\(\)' 'chars\(\)\.count\(\) as i64'

# ── a statement-position function call is bare, not block-wrapped ──
# t41: `f()` was rendered `{ f(); }` — the braces exist only so the
# expression form can carry a temporary or a trailing value.
check t41_local_var '\{ f\(\); \}' '^    f\(\);$'

# ── a call inside a capture writes to the CAPTURE, not to stdout ──
# t52: `for n in names: print(greet(n))` — the call sits inside the
# capture block, so the capture machinery MUST be present (if the sink
# context were lost the callee would print straight to stdout, the
# captured value would be empty, and the caller's print would add a
# stray blank line). Assert the capture is there and the call is inside
# it, and that the body has no blank line.
check t52_full_prog '' '__cap'
check t52_full_prog 'fn main\(\) \{\n\n' 'greet\('

# ── loops read like the source ──
# t40: nested `for i in [1, 2]: for j in [1, 2]:` — the loop vars keep
# their source names and an all-integer list is an int list, not a
# per-element parse of `["1", "2"]`.
check t40_nested_loop '__sh_lv|\.parse::<i64>\(\)' 'for i in \[1, 2\]'
check t40_nested_loop '__SHV_i|__SHV_j' 'for j in \[1, 2\]'
# t71: `range(4)` is a native Rust range over the source name, with no
# status static and no dead init store
check t71_range_loop '__sh_lv|__SHV_i' 'for i in 0\.\.=3'
check t71_range_loop 'let mut total: i64' 'let mut total = 0'

# ── a numeric f-string part needs no to_string ──
check t69_fstring 'x\.to_string\(\)' 'format!\("value=\{\}", x\)'

# ── a simple glob is a stdlib string test ──
# t68: `s.startswith("h")` must not pull in the fnmatch helper
check t68_case_glob '__sh_fnmatch' '\.starts_with\("h"\)'

# ── i64 annotations stripped from pass-2 locals when the range fits i32 ──
# analyze_i64_omittable: a proven i32-range numeric local reads as a plain
# `let` (Rust infers i32 from the unsuffixed literal), not `let x: i64`.
check t29_increment 'let mut x: i64' 'let mut x = 1'
check t41_local_var 'let y: i64' 'let y = 5'
check t48_accum 'let mut s: i64' 'let mut s = 0'
check t59_until 'let mut i: i64' 'let mut i = 0'
check t69_fstring 'let x: i64' 'let x = 7'
check t71_range_loop 'let mut total: i64' 'let mut total = 0'
check t77_pass_stmt 'let x: i64' 'let x = 1'
check t85_unary_minus 'let x: i64' 'let x = 5'
check t101_pyx_fstring 'let v: i64' 'let v = 1'

# ── string literals in &str contexts skip the .to_string() allocation ──
# The strip_str_lit_refs peephole collapses `&"lit".to_string()` to `"lit"`:
# the `&` feeds a &str parameter, and a bare &str literal coerces there
# without the String round-trip.
# __sh_replace with literal patterns inlines to std::str::replace
check t54_str_subst '&"r"\.to_string\(\)|__sh_replace' '\.replace\("p", "r"\)'
check t54_str_subst '&"ll"\.to_string\(\)|__sh_replace' '\.replace\("rr", "ll"\)'
check t60_contains '\.contains\(&"world"\.to_string\(\)\)' '\.contains\("world"\)'
check t73_dict '\.get\(&"a"\.to_string\(\)\)' '\.get\("a"\)'

echo "py-idiom-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
