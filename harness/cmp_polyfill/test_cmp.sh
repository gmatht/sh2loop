#!/bin/sh
# Comprehensive test suite for the full_cmp polyfill.
# Compares our script's output against GNU cmp on a wide range of
# inputs and flag combinations. All tests must produce byte-identical
# output (stdout+stderr) and exit codes.

CMP=/home/llm/sh2loop/harness/cmp_polyfill/cmp.sh
GNU_CMP=/usr/bin/cmp
TD=/tmp/cmp_test_$$
mkdir -p "$TD"
trap "rm -rf $TD" EXIT

pass=0; fail=0
fail_log=""

# Helper: run a test. Compares combined stdout+stderr and exit code.
# Args: description, expected_exit, our_args, file1_content, file2_content
# For convenience, the test creates the two files and runs both cmps.
run_test() {
    desc=$1; shift
    expected_rc=$1; shift
    # Remaining args: our script args, then "--", then file1 content,
    # then file2 content. Actually simpler: pass the test as a function
    # that builds files and runs.
    "$@"
    rc=$?
    if [ "$rc" = "$expected_rc" ]; then
        pass=$((pass+1))
    else
        fail=$((fail+1))
        fail_log="$fail_log\nFAIL: $desc (expected rc=$expected_rc, got $rc)"
    fi
}

# Test 1: identical single byte
test_identical_single() {
    printf 'a' > "$TD/f1"; printf 'a' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nidentical_single: expected=[$expected] actual=[$actual]"; fi
}
test_identical_single

# Test 2: differ single byte
test_differ_single() {
    printf 'a' > "$TD/f1"; printf 'b' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ndiffer_single: expected=[$expected] actual=[$actual]"; fi
}
test_differ_single

# Test 3: identical empty files
test_identical_empty() {
    : > "$TD/f1"; : > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nidentical_empty: expected=[$expected] actual=[$actual]"; fi
}
test_identical_empty

# Test 4: one empty, one not
test_empty_vs_nonempty() {
    : > "$TD/f1"; printf 'abc' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nempty_vs_nonempty: expected=[$expected] actual=[$actual]"; fi
}
test_empty_vs_nonempty

# Test 5: identical with newlines
test_identical_newlines() {
    printf 'a\nb\nc\n' > "$TD/f1"; printf 'a\nb\nc\n' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nidentical_newlines: expected=[$expected] actual=[$actual]"; fi
}
test_identical_newlines

# Test 6: differ in the middle with newlines (line counting)
test_differ_newlines() {
    printf 'a\nb\nc\nd\n' > "$TD/f1"; printf 'a\nb\nc\nd\n' > "$TD/f2"
    # Change byte 2 in f1
    printf 'X' | dd of="$TD/f1" bs=1 seek=1 count=1 conv=notrunc 2>/dev/null
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ndiffer_newlines: expected=[$expected] actual=[$actual]"; fi
}
test_differ_newlines

# Test 7: -b with newline differ
test_b_newline() {
    printf 'a\nb' > "$TD/f1"; printf 'a\nc' > "$TD/f2"
    expected=$($GNU_CMP -b "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -b "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nb_newline: expected=[$expected] actual=[$actual]"; fi
}
test_b_newline

# Test 8: -l with multiple differs
test_l_multiple() {
    printf 'abcdefghij' > "$TD/f1"; printf 'aXcdXfghij' > "$TD/f2"
    expected=$($GNU_CMP -l "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -l "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nl_multiple: expected=[$expected] actual=[$actual]"; fi
}
test_l_multiple

# Test 9: -l with no differs (identical)
test_l_identical() {
    printf 'abcdef' > "$TD/f1"; printf 'abcdef' > "$TD/f2"
    expected=$($GNU_CMP -l "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -l "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nl_identical: expected=[$expected] actual=[$actual]"; fi
}
test_l_identical

# Test 10: -s identical
test_s_identical() {
    printf 'hello' > "$TD/f1"; printf 'hello' > "$TD/f2"
    expected=$($GNU_CMP -s "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -s "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ns_identical: expected=[$expected] actual=[$actual]"; fi
}
test_s_identical

# Test 11: -s differ
test_s_differ() {
    printf 'hello' > "$TD/f1"; printf 'world' > "$TD/f2"
    expected=$($GNU_CMP -s "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -s "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ns_differ: expected=[$expected] actual=[$actual]"; fi
}
test_s_differ

# Test 12: -bs combined
test_bs() {
    printf 'abc' > "$TD/f1"; printf 'aXc' > "$TD/f2"
    expected=$($GNU_CMP -bs "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -bs "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nbs: expected=[$expected] actual=[$actual]"; fi
}
test_bs

# Test 13: -n equal to file size (identical)
test_n_equal() {
    printf 'abcde' > "$TD/f1"; printf 'abcde' > "$TD/f2"
    expected=$($GNU_CMP -n 5 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -n 5 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nn_equal: expected=[$expected] actual=[$actual]"; fi
}
test_n_equal

# Test 14: -n 0 (compare nothing)
test_n_zero() {
    printf 'abc' > "$TD/f1"; printf 'XYZ' > "$TD/f2"
    expected=$($GNU_CMP -n 0 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -n 0 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nn_zero: expected=[$expected] actual=[$actual]"; fi
}
test_n_zero

# Test 15: -n larger than both files
test_n_large() {
    printf 'ab' > "$TD/f1"; printf 'ab' > "$TD/f2"
    expected=$($GNU_CMP -n 100 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -n 100 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nn_large: expected=[$expected] actual=[$actual]"; fi
}
test_n_large

# Test 16: -i equal skips (same as no -i)
test_i_equal() {
    printf 'abcdef' > "$TD/f1"; printf 'abcdef' > "$TD/f2"
    expected=$($GNU_CMP -i 2:2 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -i 2:2 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ni_equal: expected=[$expected] actual=[$actual]"; fi
}
test_i_equal

# Test 17: -i skip past differ (identical)
test_i_skip_past() {
    printf 'abcdefghij' > "$TD/f1"; printf 'XbcdeXghij' > "$TD/f2"
    expected=$($GNU_CMP -i 1:4 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -i 1:4 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ni_skip_past: expected=[$expected] actual=[$actual]"; fi
}
test_i_skip_past

# Test 18: -i skip exactly to differ
test_i_skip_to_differ() {
    printf 'abcdef' > "$TD/f1"; printf 'abcdez' > "$TD/f2"
    expected=$($GNU_CMP -i 5 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -i 5 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ni_skip_to_differ: expected=[$expected] actual=[$actual]"; fi
}
test_i_skip_to_differ

# Test 19: binary content with high-bit chars
test_binary_highbit() {
    printf '\x80\x81\x82\x83' > "$TD/f1"; printf '\x80\x81\xff\x83' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nbinary_highbit: expected=[$expected] actual=[$actual]"; fi
}
test_binary_highbit

# Test 20: binary with -b (printable form)
test_binary_b() {
    printf '\x01\x02abc' > "$TD/f1"; printf '\x01\x03abc' > "$TD/f2"
    expected=$($GNU_CMP -b "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -b "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_g\nbinary_b: expected=[$expected] actual=[$actual]"; fi
}
test_binary_b

# Test 21: NUL bytes in file
test_nul_bytes() {
    printf 'a\x00b\x00c' > "$TD/f1"; printf 'a\x00X\x00c' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nnul_bytes: expected=[$expected] actual=[$actual]"; fi
}
test_nul_bytes

# Test 22: larger file (1KB) to test bisect
test_large_1kb() {
    # Create two 1024-byte files that differ at byte 500
    head -c 1024 /dev/zero | tr '\0' 'a' > "$TD/f1"
    head -c 1024 /dev/zero | tr '\0' 'a' > "$TD/f2"
    printf 'X' | dd of="$TD/f2" bs=1 seek=499 count=1 conv=notrunc 2>/dev/null
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nlarge_1kb: expected=[$expected] actual=[$actual]"; fi
}
test_large_1kb

# Test 23: 4KB file with differ at byte 2048 (tests bisect convergence)
test_large_4kb() {
    head -c 4096 /dev/zero | tr '\0' 'b' > "$TD/f1"
    head -c 4096 /dev/zero | tr '\0' 'b' > "$TD/f2"
    printf 'Y' | dd of="$TD/f2" bs=1 seek=2047 count=1 conv=notrunc 2>/dev/null
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nlarge_4kb: expected=[$expected] actual=[$actual]"; fi
}
test_large_4kb

# Test 24: 16KB file identical (bisect should find all equal quickly)
test_large_identical() {
    head -c 16384 /dev/zero | tr '\0' 'x' > "$TD/f1"
    head -c 16384 /dev/zero | tr '\0' 'x' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nlarge_identical: expected=[$expected] actual=[$actual]"; fi
}
test_large_identical

# Test 25: 16KB -l with multiple differs scattered
test_large_l_multi() {
    head -c 16384 /dev/zero | tr '\0' 'a' > "$TD/f1"
    head -c 16384 /dev/zero | tr '\0' 'a' > "$TD/f2"
    # Scatter differs at bytes 100, 5000, 12000
    printf 'X' | dd of="$TD/f2" bs=1 seek=99 count=1 conv=notrunc 2>/dev/null
    printf 'Y' | dd of="$TD/f2" bs=1 seek=4999 count=1 conv=notrunc 2>/dev/null
    printf 'Z' | dd of="$TD/f2" bs=1 seek=11999 count=1 conv=notrunc 2>/dev/null
    expected=$($GNU_CMP -l "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -l "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nlarge_l_multi: expected=[$expected] actual=[$actual]"; fi
}
test_large_l_multi

# Test 26: missing file error
test_missing_file() {
    printf 'a' > "$TD/f1"
    expected=$($GNU_CMP "$TD/f1" "$TD/no_such_file" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/no_such_file" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nmissing_file: expected=[$expected] actual=[$actual]"; fi
}
test_missing_file

# Test 27: directory as file
test_dir_file() {
    printf 'a' > "$TD/f1"
    mkdir -p "$TD/somedir"
    expected=$($GNU_CMP "$TD/f1" "$TD/somedir" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/somedir" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ndir_file: expected=[$expected] actual=[$actual]"; fi
}
test_dir_file

# Test 28: unreadable file
test_unreadable() {
    printf 'a' > "$TD/f1"
    printf 'a' > "$TD/f2"
    chmod 000 "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    chmod 644 "$TD/f2"  # restore for cleanup
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nunreadable: expected=[$expected] actual=[$actual]"; fi
}
test_unreadable

# Test 29: no args
test_no_args() {
    expected=$($GNU_CMP 2>&1; echo "rc=$?")
    actual=$($CMP 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nno_args: expected=[$expected] actual=[$actual]"; fi
}
test_no_args

# Test 30: one arg
test_one_arg() {
    expected=$($GNU_CMP "$TD/f1" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\none_arg: expected=[$expected] actual=[$actual]"; fi
}
test_one_arg

# Test 31: unknown flag
test_unknown_flag() {
    printf 'a' > "$TD/f1"; printf 'a' > "$TD/f2"
    expected=$($GNU_CMP -Z "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -Z "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nunknown_flag: expected=[$expected] actual=[$actual]"; fi
}
test_unknown_flag

# Test 32: -i 0 (no skip)
test_i_zero() {
    printf 'abc' > "$TD/f1"; printf 'abc' > "$TD/f2"
    expected=$($GNU_CMP -i 0 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -i 0 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ni_zero: expected=[$expected] actual=[$actual]"; fi
}
test_i_zero

# Test 33: -i 0:0
test_i_zero_zero() {
    printf 'abc' > "$TD/f1"; printf 'abc' > "$TD/f2"
    expected=$($GNU_CMP -i 0:0 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -i 0:0 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ni_zero_zero: expected=[$expected] actual=[$actual]"; fi
}
test_i_zero_zero

# Test 34: -n 1 (compare just 1 byte)
test_n_one() {
    printf 'ab' > "$TD/f1"; printf 'ab' > "$TD/f2"
    expected=$($GNU_CMP -n 1 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -n 1 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nn_one: expected=[$expected] actual=[$actual]"; fi
}
test_n_one

# Test 35: -n 1 with differ at byte 1 (should say identical within limit)
test_n_one_differ_at_1() {
    printf 'ab' > "$TD/f1"; printf 'Xb' > "$TD/f2"
    expected=$($GNU_CMP -n 1 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -n 1 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nn_one_differ_at_1: expected=[$expected] actual=[$actual]"; fi
}
test_n_one_differ_at_1

# Test 36: combined -blsn
test_blsn() {
    printf 'abcdef' > "$TD/f1"; printf 'abXdef' > "$TD/f2"
    expected=$($GNU_CMP -blsn 5 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -blsn 5 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nblsn: expected=[$expected] actual=[$actual]"; fi
}
test_blsn

# Test 37: -li combined
test_li() {
    printf 'abcdef' > "$TD/f1"; printf 'Xbcdef' > "$TD/f2"
    expected=$($GNU_CMP -li 1 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -li 1 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nli: expected=[$expected] actual=[$actual]"; fi
}
test_li

# Test 38: differ at the very last byte
test_differ_last_byte() {
    printf 'abcde' > "$TD/f1"; printf 'abcdX' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ndiffer_last_byte: expected=[$expected] actual=[$actual]"; fi
}
test_differ_last_byte

# Test 39: file1 is a prefix of file2
test_prefix() {
    printf 'abc' > "$TD/f1"; printf 'abcdef' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\nprefix: expected=[$expected] actual=[$actual]"; fi
}
test_prefix

# Test 40: both files are just newlines
test_just_newlines() {
    printf '\n\n\n' > "$TD/f1"; printf '\n\n\n' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\njust_newlines: expected=[$expected] actual=[$actual]"; fi
}
test_just_newlines

# Test 41: differ at a newline (line counting edge case)
test_differ_at_newline() {
    printf 'a\nb' > "$TD/f1"; printf 'a\nc' > "$TD/f2"
    expected=$($GNU_CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ndiffer_at_newline: expected=[$expected] actual=[$actual]"; fi
}
test_differ_at_newline

# Test 42: -i larger than file size (should ignore everything, equal)
test_i_too_large() {
    printf 'abc' > "$TD/f1"; printf 'abc' > "$TD/f2"
    expected=$($GNU_CMP -i 100 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -i 100 "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ni_too_large: expected=[$expected] actual=[$actual]"; fi
}
test_i_too_large

# Test 43: -- separator
test_dash_dash() {
    printf 'a' > "$TD/f1"; printf 'a' > "$TD/f2"
    expected=$($GNU_CMP -- "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    actual=$($CMP -- "$TD/f1" "$TD/f2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\ndash_dash: expected=[$expected] actual=[$actual]"; fi
}
test_dash_dash

# Test 44: 070 corpus test cases
test_070_corpus() {
    # Recreate the exact 070 test files
    echo "abcdefghij" > "$TD/a"
    echo "abcdefghij" > "$TD/s"
    printf 'abcdeZghij' > "$TD/d"
    printf 'xyzdefghij' > "$TD/d2"
    echo "abc" > "$TD/sh"
    : > "$TD/e"
    expected=$($GNU_CMP "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_differ: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -b "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -b "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_b: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -l "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -l "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_l: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -s "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -s "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_s: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -n 5 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -n 5 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_n5: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -n 10 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -n 10 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_n10: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -n 10 "$TD/a" "$TD/sh" 2>&1; echo "rc=$?")
    actual=$($CMP -n 10 "$TD/a" "$TD/sh" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_n10short: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -i 6 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -i 6 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_i6: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -i 3 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -i 3 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_i3: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -i 0:6 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    actual=$($CMP -i 0:6 "$TD/a" "$TD/d" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_i06: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP -i 5:0 "$TD/a" "$TD/d2" 2>&1; echo "rc=$?")
    actual=$($CMP -i 5:0 "$TD/a" "$TD/d2" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_i50: expected=[$expected] actual=[$actual]"; fi

    expected=$($GNU_CMP "$TD/a" "$TD/e" 2>&1; echo "rc=$?")
    actual=$($CMP "$TD/a" "$TD/e" 2>&1; echo "rc=$?")
    if [ "$expected" = "$actual" ]; then pass=$((pass+1))
    else fail=$((fail+1)); fail_log="$fail_log\n070_empty: expected=[$expected] actual=[$actual]"; fi
}
test_070_corpus

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
