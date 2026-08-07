#!/bin/sh
# Comprehensive test suite for the full_cmp polyfill.
# Compares our script's output against GNU cmp. All tests must
# produce byte-identical output (stdout+stderr) and exit codes,
# EXCEPT the program-name prefix in error messages (which differs
# by design: GNU uses "/usr/bin/cmp" or "cmp"; ours uses its
# invocation path). The normalize() helper strips that prefix.

CMP=/home/llm/sh2loop/harness/cmp_polyfill/cmp.sh
GNU_CMP=/usr/bin/cmp
TD=/tmp/cmp_test_$$
mkdir -p "$TD"
trap "rm -rf $TD" EXIT

pass=0; fail=0
fail_log=""

# Normalize: strip program-name prefix from the first line of error
# messages. GNU uses "/usr/bin/cmp:" (its argv[0]) or "cmp:" (in the
# differ/EOF message). Our script uses its invocation path. Compare
# the message CONTENT after the prefix.
normalize() {
    # If the first line matches "^[^:]*: ", strip up to and including ": "
    awk 'NR==1 { if (match($0, /^[^:]*: /)) { print substr($0, RLENGTH+1); next } } { print }'
}

# Run a full cmp test. Compares rc and normalized output.
# Args: description, our_cmd (string), gnu_cmd (string)
run() {
    desc=$1; shift
    our_cmd=$1; shift
    gnu_cmd=$1; shift
    our_out=$(eval "$CMP $our_cmd" 2>&1; echo "rc=$?")
    gnu_out=$(eval "$GNU_CMP $gnu_cmd" 2>&1; echo "rc=$?")
    our_norm=$(echo "$our_out" | normalize)
    gnu_norm=$(echo "$gnu_out" | normalize)
    if [ "$our_norm" = "$gnu_norm" ]; then
        pass=$((pass+1))
    else
        fail=$((fail+1))
        fail_log="$fail_log\nFAIL: $desc\n  GNU: [$gnu_out]\n  OUR: [$our_out]"
    fi
}

# Create a test file with printf %b content
mkfile() {
    printf '%b' "$2" > "$TD/$1"
}

# ===== Basic functionality =====
mkfile f1 'a'; mkfile f2 'a'
run "identical_single" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"

mkfile f1 'a'; mkfile f2 'b'
run "differ_single" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"

mkfile f1 ''; mkfile f2 ''
run "identical_empty" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"

mkfile f1 ''; mkfile f2 'abc'
run "empty_vs_nonempty" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"

mkfile f1 'a\nb\nc\n'; mkfile f2 'a\nb\nc\n'
run "identical_newlines" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"

mkfile f1 'a\nb\nc\nd\n'; mkfile f2 'a\nb\nc\nd\n'
printf 'X' | dd of="$TD/f1" bs=1 seek=1 count=1 conv=notrunc 2>/dev/null
run "differ_newlines" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"

mkfile f1 'a\nb'; mkfile f2 'a\nc'
run "b_newline" "-b '$TD/f1' '$TD/f2'" "-b '$TD/f1' '$TD/f2'"

mkfile f1 'abcdefghij'; mkfile f2 'aXcdXfghij'
run "l_multiple" "-l '$TD/f1' '$TD/f2'" "-l '$TD/f1' '$TD/f2'"

mkfile f1 'abcdef'; mkfile f2 'abcdef'
run "l_identical" "-l '$TD/f1' '$TD/f2'" "-l '$TD/f1' '$TD/f2'"

mkfile f1 'hello'; mkfile f2 'hello'
run "s_identical" "-s '$TD/f1' '$TD/f2'" "-s '$TD/f1' '$TD/f2'"
mkfile f2 'world'
run "s_differ" "-s '$TD/f1' '$TD/f2'" "-s '$TD/f1' '$TD/f2'"

mkfile f1 'abc'; mkfile f2 'aXc'
run "bs" "-bs '$TD/f1' '$TD/f2'" "-bs '$TD/f1' '$TD/f2'"

run "n_equal" "-n 5 '$TD/f1' '$TD/f2'" "-n 5 '$TD/f1' '$TD/f2'"
mkfile f1 'abc'; mkfile f2 'XYZ'
run "n_zero" "-n 0 '$TD/f1' '$TD/f2'" "-n 0 '$TD/f1' '$TD/f2'"

mkfile f1 'ab'; mkfile f2 'ab'
run "n_large" "-n 100 '$TD/f1' '$TD/f2'" "-n 100 '$TD/f1' '$TD/f2'"
run "n_one" "-n 1 '$TD/f1' '$TD/f2'" "-n 1 '$TD/f1' '$TD/f2'"

mkfile f1 'ab'; mkfile f2 'Xb'
run "n_one_differ_at_1" "-n 1 '$TD/f1' '$TD/f2'" "-n 1 '$TD/f1' '$TD/f2'"

mkfile f1 'abcde'; mkfile f2 'abcde'
run "i_equal" "-i 2:2 '$TD/f1' '$TD/f2'" "-i 2:2 '$TD/f1' '$TD/f2'"
mkfile f1 'abcdefghij'; mkfile f2 'XbcdeXghij'
run "i_skip_past" "-i 1:4 '$TD/f1' '$TD/f2'" "-i 1:4 '$TD/f1' '$TD/f2'"
mkfile f1 'abcdef'; mkfile f2 'abcdez'
run "i_skip_to_differ" "-i 5 '$TD/f1' '$TD/f2'" "-i 5 '$TD/f1' '$TD/f2'"

# Binary content
printf '\x80\x81\x82\x83' > "$TD/f1"
printf '\x80\x81\xff\x83' > "$TD/f2"
run "binary_highbit" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"
printf '\x01\x02abc' > "$TD/f1"
printf '\x01\x03abc' > "$TD/f2"
run "binary_b" "-b '$TD/f1' '$TD/f2'" "-b '$TD/f1' '$TD/f2'"
printf 'a\x00b\x00c' > "$TD/f1"
printf 'a\x00X\x00c' > "$TD/f2"
run "nul_bytes" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"

# Larger files
head -c 1024 /dev/zero | tr '\0' 'a' > "$TD/big1"
head -c 1024 /dev/zero | tr '\0' 'a' > "$TD/big2"
printf 'X' | dd of="$TD/big2" bs=1 seek=499 count=1 conv=notrunc 2>/dev/null
run "large_1kb" "'$TD/big1' '$TD/big2'" "'$TD/big1' '$TD/big2'"
head -c 4096 /dev/zero | tr '\0' 'b' > "$TD/big1"
head -c 4096 /dev/zero | tr '\0' 'b' > "$TD/big2"
printf 'Y' | dd of="$TD/big2" bs=1 seek=2047 count=1 conv=notrunc 2>/dev/null
run "large_4kb" "'$TD/big1' '$TD/big2'" "'$TD/big1' '$TD/big2'"
head -c 16384 /dev/zero | tr '\0' 'x' > "$TD/big1"
head -c 16384 /dev/zero | tr '\0' 'x' > "$TD/big2"
run "large_identical" "'$TD/big1' '$TD/big2'" "'$TD/big1' '$TD/big2'"
head -c 16384 /dev/zero | tr '\0' 'a' > "$TD/big1"
head -c 16384 /dev/zero | tr '\0' 'a' > "$TD/big2"
printf 'X' | dd of="$TD/big2" bs=1 seek=99 count=1 conv=notrunc 2>/dev/null
printf 'Y' | dd of="$TD/big2" bs=1 seek=4999 count=1 conv=notrunc 2>/dev/null
printf 'Z' | dd of="$TD/big2" bs=1 seek=11999 count=1 conv=notrunc 2>/dev/null
run "large_l_multi" "-l '$TD/big1' '$TD/big2'" "-l '$TD/big1' '$TD/big2'"

# Error conditions (rc only — message format differs)
mkfile f1 'a'
run "missing_file" "'$TD/f1' '$TD/no_such_file'" "'$TD/f1' '$TD/no_such_file'"
run "dir_file" "'$TD/f1' '$TD'" "'$TD/f1' '$TD'"  # $TD is a dir
chmod 000 "$TD/f2"
mkfile f2 'a'
run "unreadable" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"
chmod 644 "$TD/f2"

# Edge cases
mkfile f1 'abcde'; mkfile f2 'abcdX'
run "differ_last_byte" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"
mkfile f1 'abc'; mkfile f2 'abcdef'
run "prefix" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"
mkfile f1 '\n\n\n'; mkfile f2 '\n\n\n'
run "just_newlines" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"
mkfile f1 'a\nb'; mkfile f2 'a\nc'
run "differ_at_newline" "'$TD/f1' '$TD/f2'" "'$TD/f1' '$TD/f2'"
run "i_zero" "-i 0 '$TD/f1' '$TD/f2'" "-i 0 '$TD/f1' '$TD/f2'"
run "i_zero_zero" "-i 0:0 '$TD/f1' '$TD/f2'" "-i 0:0 '$TD/f1' '$TD/f2'"
mkfile f1 'abc'; mkfile f2 'abc'
run "i_too_large" "-i 100 '$TD/f1' '$TD/f2'" "-i 100 '$TD/f1' '$TD/f2'"
run "dash_dash" "-- '$TD/f1' '$TD/f2'" "-- '$TD/f1' '$TD/f2'"

# 070 corpus test cases
printf 'abcdefghij\n' > "$TD/a"
printf 'abcdefghij\n' > "$TD/s"
printf 'abcdeZghij' > "$TD/d"
printf 'xyzdefghij' > "$TD/d2"
printf 'abc\n' > "$TD/sh"
: > "$TD/e"
run "070_differ" "'$TD/a' '$TD/d'" "'$TD/a' '$TD/d'"
run "070_b" "-b '$TD/a' '$TD/d'" "-b '$TD/a' '$TD/d'"
run "070_l" "-l '$TD/a' '$TD/d'" "-l '$TD/a' '$TD/d'"
run "070_s" "-s '$TD/a' '$TD/d'" "-s '$TD/a' '$TD/d'"
run "070_n5" "-n 5 '$TD/a' '$TD/d'" "-n 5 '$TD/a' '$TD/d'"
run "070_n10" "-n 10 '$TD/a' '$TD/d'" "-n 10 '$TD/a' '$TD/d'"
run "070_n10short" "-n 10 '$TD/a' '$TD/sh'" "-n 10 '$TD/a' '$TD/sh'"
run "070_i6" "-i 6 '$TD/a' '$TD/d'" "-i 6 '$TD/a' '$TD/d'"
run "070_i3" "-i 3 '$TD/a' '$TD/d'" "-i 3 '$TD/a' '$TD/d'"
run "070_i06" "-i 0:6 '$TD/a' '$TD/d'" "-i 0:6 '$TD/a' '$TD/d'"
run "070_i50" "-i 5:0 '$TD/a' '$TD/d2'" "-i 5:0 '$TD/a' '$TD/d2'"
run "070_empty" "'$TD/a' '$TD/e'" "'$TD/a' '$TD/e'"

# Summary
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
