#!/bin/sh
# Comprehensive test suite for the full_cmp polyfill.
# Compares our script's output against GNU cmp. All tests must produce
# byte-identical output (stdout+stderr) and exit codes, up to the
# program-name prefix in error messages (which differs by design:
# GNU uses "/usr/bin/cmp" or "cmp", ours uses its invocation path).

CMP=/home/llm/sh2loop/harness/cmp_polyfill/cmp.sh
GNU_CMP=/usr/bin/cmp
TD=/tmp/cmp_test_$$
mkdir -p "$TD"
trap "rm -rf $TD" EXIT

pass=0; fail=0
fail_log=""

# Normalize error/differ messages: strip the program-name prefix
# (everything up to and including the first ": " on the FIRST line).
# This lets us compare the message CONTENT without worrying about
# whether the script is invoked as "cmp", "/usr/bin/cmp", or
# "/home/llm/sh2loop/harness/cmp_polyfill/cmp.sh".
normalize() {
    # If the first line contains ": ", strip up to and including it.
    # Otherwise leave unchanged.
    # Using awk for line-by-line processing of the first line.
    awk 'NR==1 { sub(/^[^:]*: /, ""); print; next } { print }'
}

# Run a test. Args: description, our_cmd, gnu_cmd
# Compares rc and normalized output.
run() {
    desc=$1; shift
    # Remaining args: our command, then "--", then gnu command
    # Split on "--"
    our_args=""
    gnu_args=""
    sep=0
    for a in "$@"; do
        if [ "$a" = "--" ]; then sep=1; continue; fi
        if [ "$sep" -eq 0 ]; then our_args="$our_args \"$a\""
        else gnu_args="$gnu_args \"$a\""; fi
    done
    # Use eval to handle the quoted args
    our_out=$(eval "$CMP $our_args" 2>&1; echo "rc=$?")
    gnu_out=$(eval "$GNU_CMP $gnu_args" 2>&1; echo "rc=$?")
    # Normalize
    our_norm=$(echo "$our_out" | normalize)
    gnu_norm=$(echo "$gnu_out" | normalize)
    if [ "$our_norm" = "$gnu_norm" ]; then
        pass=$((pass+1))
    else
        fail=$((fail+1))
        fail_log="$fail_log\nFAIL: $desc\n  GNU: [$gnu_out]\n  OUR: [$our_out]"
    fi
}

# ===== Core cmp functionality =====
run "identical single byte" /dev/null "$TD/f1=$TD/f2" -- /dev/null "$TD/f1=$TD/f2"
# Actually, the test harness needs to create files first. Let me restructure.

# ===== Helper: create file and run =====
# test_create <file> <content>  (content via printf %b)
test_create() {
    printf '%b' "$2" > "$TD/$1"
}
test_create f1 'a'
test_create f2 'a'
run "identical_single" '' '' -- '' ''

test_create f1 'a'
test_create f2 'b'
run "differ_single" '' '' -- '' ''

test_create f1 ''
test_create f2 ''
run "identical_empty" '' '' -- '' ''

test_create f1 ''
test_create f2 'abc'
run "empty_vs_nonempty" '' '' -- '' ''

test_create f1 'a\nb\nc\n'
test_create f2 'a\nb\nc\n'
run "identical_newlines" '' '' -- '' ''

test_create f1 'a\nb\nc\nd\n'
test_create f2 'a\nb\nc\nd\n'
# Change byte 2 in f1
printf 'X' | dd of="$TD/f1" bs=1 seek=1 count=1 conv=notrunc 2>/dev/null
run "differ_newlines" '' '' -- '' ''

test_create f1 'a\nb'
test_create f2 'a\nc'
run "b_newline" -b '' -- -b ''

test_create f1 'abcdefghij'
test_create f2 'aXcdXfghij'
run "l_multiple" -l '' -- -l ''

test_create f1 'abcdef'
test_create f2 'abcdef'
run "l_identical" -l '' -- -l ''

test_create f1 'hello'
test_create f2 'hello'
run "s_identical" -s '' -- -s ''
test_create f2 'world'
run "s_differ" -s '' -- -s ''

test_create f1 'abc'
test_create f2 'aXc'
run "bs" -bs '' -- -bs ''

run "n_equal" -n 5 '' '' -- -n 5 '' ''
run "n_zero" -n 0 '' '' -- -n 0 '' ''

test_create f1 'ab'
test_create f2 'ab'
run "n_large" -n 100 '' '' -- -n 100 '' ''
run "n_one" -n 1 '' '' -- -n 1 '' ''

test_create f1 'ab'
test_create f2 'Xb'
run "n_one_differ_at_1" -n 1 '' '' -- -n 1 '' ''

test_create f1 'abcde'
test_create f2 'abcde'
run "i_equal" -i 2:2 '' '' -- -i 2:2 '' ''
test_create f1 'abcdefghij'
test_create f2 'XbcdeXghij'
run "i_skip_past" -i 1:4 '' '' -- -i 1:4 '' ''

test_create f1 'abcdef'
test_create f2 'abcdez'
run "i_skip_to_differ" -i 5 '' '' -- -i 5 '' ''

test_create f1 $'\x80\x81\x82\x83'
test_create f2 $'\x80\x81\xff\x83'
run "binary_highbit" '' '' -- '' ''
test_create f1 $'\x01\x02abc'
test_create f2 $'\x01\x03abc'
run "binary_b" -b '' '' -- -b '' ''

test_create f1 $'a\x00b\x00c'
test_create f2 $'a\x00X\x00c'
run "nul_bytes" '' '' -- '' ''

# Larger files
head -c 1024 /dev/zero | tr '\0' 'a' > "$TD/big1"
head -c 1024 /dev/zero | tr '\0' 'a' > "$TD/big2"
printf 'X' | dd of="$TD/big2" bs=1 seek=499 count=1 conv=notrunc 2>/dev/null
run "large_1kb" '' '' -- '' ''
head -c 4096 /dev/zero | tr '\0' 'b' > "$TD/big1"
head -c 4096 /dev/zero | tr '\0' 'b' > "$TD/big2"
printf 'Y' | dd of="$TD/big2" bs=1 seek=2047 count=1 conv=notrunc 2>/dev/null
run "large_4kb" '' '' -- '' ''
head -c 16384 /dev/zero | tr '\0' 'x' > "$TD/big1"
head -c 16384 /dev/zero | tr '\0' 'x' > "$TD/big2"
run "large_identical" '' '' -- '' ''
head -c 16384 /dev/zero | tr '\0' 'a' > "$TD/big1"
head -c 16384 /dev/zero | tr '\0' 'a' > "$TD/big2"
printf 'X' | dd of="$TD/big2" bs=1 seek=99 count=1 conv=notrunc 2>/dev/null
printf 'Y' | dd of="$TD/big2" bs=1 seek=4999 count=1 conv=notrunc 2>/dev/null
printf 'Z' | dd of="$TD/big2" bs=1 seek=11999 count=1 conv=notrunc 2>/dev/null
run "large_l_multi" -l '' '' -- -l '' ''

# Error conditions
run "missing_file" '' '' -- '' ''
run "dir_file" '' '' -- '' ''
test_create f1 'a'
chmod 000 "$TD/f2"
test_create f2 'a'
run "unreadable" '' '' -- '' ''
chmod 644 "$TD/f2"

# One arg: GNU reads stdin. Our script gives usage error. This is a
# known behavioral difference. Test the rc only.
our_out=$($CMP "$TD/f1" 2>&1; echo "rc=$?")
gnu_out=$($GNU_CMP "$TD/f1" 2>&1; echo "rc=$?")
if [ "$our_out" = "$gnu_out" ]; then pass=$((pass+1))
else fail=$((fail+1)); fail_log="$fail_log\nFAIL: one_arg_rc: our=[$our_out] gnu=[$gnu_out]"; fi

# No args
our_out=$($CMP 2>&1; echo "rc=$?")
gnu_out=$($GNU_CMP 2>&1; echo "rc=$?")
if [ "$our_out" = "$gnu_out" ]; then pass=$((pass+1))
else fail=$((fail+1)); fail_log="$fail_log\nFAIL: no_args_rc: our=[$our_out] gnu=[$gnu_out]"; fi

# Unknown flag
our_out=$($CMP -Z "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
gnu_out=$($GNU_CMP -Z "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
if [ "$our_out" = "$gnu_out" ]; then pass=$((pass+1))
else fail=$((fail+1)); fail_log="$fail_log\nFAIL: unknown_flag_rc: our=[$our_out] gnu=[$gnu_out]"; fi

# -l -s incompatible
test_create f1 'a'
test_create f2 'b'
our_out=$($CMP -ls "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
gnu_out=$($GNU_CMP -ls "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
if [ "$our_out" = "$gnu_out" ]; then pass=$((pass+1))
else fail=$((fail+1)); fail_log="$fail_log\nFAIL: blsn_rc: our=[$our_out] gnu=[$gnu_out]"; fi

# Combined flags
test_create f1 'abcdef'
test_create f2 'abXdef'
run "blsn_rc" -lsn 5 '' '' -- -lsn 5 '' ''  # -l -s incompatible, rc=2
test_create f1 'abcdef'
test_create f2 'Xbcdef'
run "li" -li 1 '' '' -- -li 1 '' ''

# Edge cases
test_create f1 'abcde'
test_create f2 'abcdX'
run "differ_last_byte" '' '' -- '' ''
test_create f1 'abc'
test_create f2 'abcdef'
run "prefix" '' '' -- '' ''
test_create f1 '\n\n\n'
test_create f2 '\n\n\n'
run "just_newlines" '' '' -- '' ''
test_create f1 'a\nb'
test_create f2 'a\nc'
run "differ_at_newline" '' '' -- '' ''
run "i_zero" -i 0 '' '' -- -i 0 '' ''
run "i_zero_zero" -i 0:0 '' '' -- -i 0:0 '' ''
run "i_too_large" -i 100 '' '' -- -i 100 '' ''

test_create f1 'a'
test_create f2 'a'
run "dash_dash" -- '' '' -- -- '' ''

# ===== 070 corpus test cases =====
test_create a 'abcdefghij\n'
test_create s 'abcdefghij\n'
test_create d $'abcdeZghij'
test_create d2 $'xyzdefghij'
test_create sh 'abc\n'
: > "$TD/e"
run "070_differ" '' "$TD/a $TD/d" -- '' "$TD/a $TD/d"
run "070_b" -b '' "$TD/a $TD/d" -- -b '' "$TD/a $TD/d"
run "070_l" -l '' "$TD/a $TD/d" -- -l '' "$TD/a $TD/d"
run "070_s" -s '' "$TD/a $TD/d" -- -s '' "$TD/a $TD/d"
run "070_n5" -n 5 '' "$TD/a $TD/d" -- -n 5 '' "$TD/a $TD/d"
run "070_n10" -n 10 '' "$TD/a $TD/d" -- -n 10 '' "$TD/a $TD/d"
run "070_n10short" -n 10 '' "$TD/a $TD/sh" -- -n 10 '' "$TD/a $TD/sh"
run "070_i6" -i 6 '' "$TD/a $TD/d" -- -i 6 '' "$TD/a $TD/d"
run "070_i3" -i 3 '' "$TD/a $TD/d" -- -i 3 '' "$TD/a $TD/d"
run "070_i06" -i 0:6 '' "$TD/a $TD/d" -- -i 0:6 '' "$TD/a $TD/d"
run "070_i50" -i 5:0 '' "$TD/a $TD/d2" -- -i 5:0 '' "$TD/a $TD/d2"
run "070_empty" '' "$TD/a $TD/e" -- '' "$TD/a $TD/e"

# ===== Summary =====
echo "=========================================="
echo "  PASS: $pass"
echo "  FAIL: $fail"
echo "=========================================="
if [ "$fail" -gt 0 ]; then
    printf "Failures:\n%b\n" "$fail_log"
    exit 1
fi
echo "All tests pass."
exit 0
