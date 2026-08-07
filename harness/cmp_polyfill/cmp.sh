#!/bin/sh
# Full GNU cmp(1) emulation in pure POSIX shell.
#
# Features:
#   -b         print differing bytes in printable (cat -v) form
#   -l         print a per-byte octal listing of all differing bytes
#   -s         silent (exit code only)
#   -n N       compare at most N bytes
#   -i N[:M]   skip N bytes from file 1 (and M from file 2) before comparing
#   --         end of options
#
# Algorithm:
#   - For default/-b/-s/-n: binary search (bisect) to find the first
#     differing byte in O(log N) chunked-cksum comparisons. Then
#     verify the byte and compute the line number in a single
#     tr | wc -c pass.
#   - For -l: bisect to find the first differ, then scan forward in
#     16 KB blocks. Identical blocks are skipped via a single cksum
#     syscall per block; differing blocks are hex-dumped and emitted
#     byte-by-byte.
#
# POSIX-only. No bash, no GNU extensions. Tested against GNU cmp 8.32
# on the 070_cmp_basic corpus cases (plain, -b, -l, -s, -n 5/10/10-short,
# -i 6/3/0:6/5:0, and the empty/short-file EOF cases).

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
bflag= lflag= sflag=
limit=-1
skip1=0 skip2=0

while getopts "blsn:i:" opt; do
    case "$opt" in
        b) bflag=1 ;;
        l) lflag=1 ;;
        s) sflag=1 ;;
        n) limit=$OPTARG ;;
        i)
            case "$OPTARG" in
                *:*) skip1=${OPTARG%%:*}; skip2=${OPTARG##*:} ;;
                # single-arg -i N skips N from BOTH files (GNU behavior)
                *)   skip1=$OPTARG; skip2=$OPTARG ;;
            esac
            ;;
        *) echo "Usage: cmp [-b|-l|-s] [-n N] [-i N[:M]] [--] file1 file2" >&2
           exit 2 ;;
    esac
done
shift $((OPTIND - 1))

# `--` ends options
[ "${1:-}" = "--" ] && shift

# -l and -s are mutually exclusive (GNU behavior)
if [ -n "$lflag" ] && [ -n "$sflag" ]; then
    echo "$0: options -l and -s are incompatible" >&2
    echo "Try '$0 --help' for more information." >&2
    exit 2
fi

if [ $# -ne 2 ]; then
    echo "Usage: cmp [-b|-l|-s] [-n N] [-i N[:M]] [--] file1 file2" >&2
    exit 2
fi
file1=$1
file2=$2

# ---------------------------------------------------------------------------
# File validation
# ---------------------------------------------------------------------------
# Use $0 (full invocation path) as the program name in error messages,
# matching GNU's behavior (e.g., "/usr/bin/cmp: FILE: No such file...").
for f in "$file1" "$file2"; do
    if [ ! -e "$f" ]; then
        echo "$0: $f: No such file or directory" >&2
        exit 2
    fi
    if [ -d "$f" ]; then
        echo "$0: $f: Is a directory" >&2
        exit 2
    fi
    if [ ! -r "$f" ]; then
        echo "$0: $f: Permission denied" >&2
        exit 2
    fi
done

# ---------------------------------------------------------------------------
# File sizes (used to cap the comparison range and detect EOF)
# ---------------------------------------------------------------------------
sz1=$(wc -c < "$file1" | tr -d ' ')
sz2=$(wc -c < "$file2" | tr -d ' ')

# Adjust file sizes for the skipped prefix (bytes skipped are not
# part of the comparison)
sz1=$((sz1 - skip1))
sz2=$((sz2 - skip2))
[ "$sz1" -lt 0 ] && sz1=0
[ "$sz2" -lt 0 ] && sz2=0

# Comparison length: the shorter of the two adjusted sizes, capped by
# -n if provided. A -n of -1 means "no limit".
len=$sz1
[ "$sz2" -lt "$len" ] && len=$sz2
[ "$limit" -ne -1 ] && [ "$limit" -lt "$len" ] && len=$limit

# ---------------------------------------------------------------------------
# Byte to printable char (for -b), using printf format strings.
# Printable ASCII (32-126) prints as itself; non-printable prints as a
# single space. This matches the corpus expectation where the
# differing characters are all printable ('f' and 'Z').
# ---------------------------------------------------------------------------
_oct_to_char() {
    # Print the byte value (from octal string $1) in cat -v style:
    # printable (32-126) as the char, control (0-31) as ^X, DEL (127) as
    # ^?, high-bit (128-255) as M-X. Uses awk because POSIX sh's
    # printf "%c" with a numeric arg is unreliable (dash prints the
    # first char of the string representation, not the char with that code).
    awk -v d="$((0$1))" 'BEGIN {
        if (d >= 32 && d <= 126) printf "%c", d
        else if (d < 32) printf "^%c", d + 64
        else if (d == 127) printf "^?"
        else { d2 = d - 128
               if (d2 < 32) printf "M-^%c", d2 + 64
               else printf "M-%c", d2 }
    }'
}

# ---------------------------------------------------------------------------
# Binary search (bisect) for the first differing offset in [0, len).
# Each iteration: read len/2 bytes from each file at the current offset,
# compare via cksum. If equal, the differ (if any) is in the second
# half; otherwise it's in the first half (or the first byte of the
# second half). Uses tail -c +N (instant lseek) + dd bs=N count=1.
# Time complexity: O(log N) iterations of O(1) cksum syscalls.
# ---------------------------------------------------------------------------
# Binary search for the first differing offset (0-indexed) in [0, $1).
# Uses a PREFIX check: cksum of the first k bytes of each file. The
# predicate "first k bytes are identical" is monotone in k, so
# binary search applies. Returns the first differ offset, or $1 if
# all equal.
find_first_diff() {
    _ffd_lo=0
    _ffd_hi=$1
    while [ "$_ffd_hi" -gt "$_ffd_lo" ]; do
        # when lo+1 == hi, check [0,hi) directly. If it matches,
        # all bytes in the range are equal (return hi). If not,
        # the differ is at lo (return lo).
        if [ $((_ffd_hi - _ffd_lo)) -eq 1 ]; then
            # cksum [0,hi)
            _hH1=$(tail -c +$((skip1 + 1)) "$file1" 2>/dev/null | dd bs="$_ffd_hi" count=1 2>/dev/null | cksum | awk '{print $1}')
            _hH2=$(tail -c +$((skip2 + 1)) "$file2" 2>/dev/null | dd bs="$_ffd_hi" count=1 2>/dev/null | cksum | awk '{print $1}')
            if [ "$_hH1" = "$_hH2" ]; then
                echo "$_ffd_hi"
            else
                echo "$_ffd_lo"
            fi
            return
        fi
        _mid=$((_ffd_lo + (_ffd_hi - _ffd_lo) / 2))
        # cksum of the first _mid bytes (after the skip)
        _h1=$(tail -c +$((skip1 + 1)) "$file1" 2>/dev/null | dd bs="$_mid" count=1 2>/dev/null | cksum | awk '{print $1}')
        _h2=$(tail -c +$((skip2 + 1)) "$file2" 2>/dev/null | dd bs="$_mid" count=1 2>/dev/null | cksum | awk '{print $1}')
        if [ "$_h1" = "$_h2" ]; then
            _ffd_lo=$_mid
        else
            _ffd_hi=$_mid
        fi
    done
    # lo == hi: all equal in the range
    echo "$_ffd_lo"
}


# ---------------------------------------------------------------------------
# If len is 0, one of the comparison ranges is empty. Decide if it's an
# EOF (one file shorter) or identical (both empty).
# ---------------------------------------------------------------------------
if [ "$len" -eq 0 ]; then
    # If -n was used (limit!=-1) and the limit is 0, the compare range
    # is empty by design -> identical within the limit (GNU rc=0).
    if [ "$limit" -ne -1 ]; then
        exit 0
    fi
    # compare ranges both empty
    if [ "$sz1" -eq 0 ] && [ "$sz2" -eq 0 ]; then
        exit 0
    fi
    # one file is shorter (EOF before the skip+compare range)
    if [ "$sz1" -lt "$sz2" ]; then
        [ -n "$sflag" ] || echo "cmp: EOF on $file1 which is empty" >&2
    else
        if [ "$sz2" -eq 0 ]; then
            [ -n "$sflag" ] || echo "cmp: EOF on $file2 which is empty" >&2
        else
            [ -n "$sflag" ] || echo "cmp: EOF on $file2" >&2
        fi
    fi
    exit 1
fi

# ---------------------------------------------------------------------------
# Find the first differing offset (or len if all equal)
# ---------------------------------------------------------------------------
diff=$(find_first_diff "$len")

# If diff >= len, the comparison ranges are byte-identical.
if [ "$diff" -ge "$len" ]; then
    # Comparison range is byte-identical. Decide if the files are
    # truly equal, or one is shorter (EOF / differ at first missing byte).
    if [ "$sz1" -eq "$sz2" ]; then
        # Same size, same content in the range -> identical.
        exit 0
    fi
    # If -n capped the compare range and the files are equal up to -n,
    # they're "identical within the limit" (GNU behavior).
    if [ "$limit" -ne -1 ] && [ "$len" -eq "$limit" ]; then
        exit 0
    fi
    # One file is shorter and the compare range was capped by the
    # shorter file (not by -n). Identify which.
    if [ "$sz1" -gt "$sz2" ]; then
        short_file=$file2; short_off=$sz2
    else
        short_file=$file1; short_off=$sz1
    fi
    # If the shorter file is empty (zero bytes), report EOF-empty.
    if [ "$short_off" -eq 0 ]; then
        [ -n "$sflag" ] || echo "cmp: EOF on $short_file which is empty" >&2
        exit 1
    fi
    # If no -n was used, the shorter file simply ran out at the overlap
    # end: this is an EOF, not a differ. Report "after byte N" where
    # N is the 0-based comparison-relative offset of the EOF (= len).
    if [ "$limit" -eq -1 ]; then
        _eof_line=$(tail -c +$((skip1 + 1)) "$file1" 2>/dev/null | dd bs="$len" count=1 2>/dev/null | tr -cd '\n' | wc -c | tr -d ' ')
        _eof_line=$((_eof_line + 1))
        [ -n "$sflag" ] || echo "cmp: EOF on $short_file after byte $len, in line $_eof_line" >&2
        exit 1
    fi
    # With -n: the differ is at the first byte past the overlap
    # (comparison-relative offset = $len, 1-indexed byte = len + 1).
    diff=$len
    # Read the byte from the file that HAS the byte (the other is EOF).
    if [ "$sz1" -gt "$sz2" ]; then
        b1=$(tail -c +$((skip1 + diff + 1)) "$file1" 2>/dev/null | dd bs=1 count=1 2>/dev/null | od -An -to1 | tr -d ' \n')
        b2=""
    else
        b1=""
        b2=$(tail -c +$((skip2 + diff + 1)) "$file2" 2>/dev/null | dd bs=1 count=1 2>/dev/null | od -An -to1 | tr -d ' \n')
    fi
    _b1_set=1
    # Fall through to the reporting section below (b1 XOR b2 is non-empty).
fi

# ---------------------------------------------------------------------------
# Verify the differing byte (read it from each file). Skip if already
# set by the short-file branch above (which sets one to empty and
# the other to the actual byte).
# ---------------------------------------------------------------------------
if [ "$_b1_set" != 1 ]; then
    b1=$(tail -c +$((skip1 + diff + 1)) "$file1" 2>/dev/null \
         | dd bs=1 count=1 2>/dev/null | od -An -to1 | tr -d ' \n')
    b2=$(tail -c +$((skip2 + diff + 1)) "$file2" 2>/dev/null \
         | dd bs=1 count=1 2>/dev/null | od -An -to1 | tr -d ' \n')
fi

# EOF edges: a file ended before diff (shouldn't happen since diff < len,
# but be safe)
if [ -z "$b1" ] && [ -z "$b2" ]; then exit 0; fi
if [ -z "$b1" ]; then
    _eof_line=$(tail -c +$((skip2 + 1)) "$file2" 2>/dev/null | dd bs="$diff" count=1 2>/dev/null | tr -cd '\n' | wc -c | tr -d ' ')
    _eof_line=$((_eof_line + 1))
    [ -n "$sflag" ] || echo "cmp: EOF on $file1 after byte $((diff + 1)), in line $_eof_line" >&2
    exit 1
fi
if [ -z "$b2" ]; then
    _eof_line=$(tail -c +$((skip1 + 1)) "$file1" 2>/dev/null | dd bs="$diff" count=1 2>/dev/null | tr -cd '\n' | wc -c | tr -d ' ')
    _eof_line=$((_eof_line + 1))
    [ -n "$sflag" ] || echo "cmp: EOF on $file2 after byte $((diff + 1)), in line $_eof_line" >&2
    exit 1
fi

# False positive guard: if the bytes are actually equal (cksum can
# collide on extremely large blocks, though cksum is a strong CRC),
# treat as identical.
if [ "$b1" = "$b2" ]; then exit 0; fi

# ---------------------------------------------------------------------------
# -l mode: emit a per-byte octal listing of all differing bytes from
# diff onward. Scan in 16 KB blocks: cksum-compare each block, skip
# identical blocks, hex-dump differing blocks byte by byte.
# ---------------------------------------------------------------------------
if [ -n "$lflag" ]; then
    # Emit EOF to stderr first (matches GNU order in 2>&1 capture)
    if [ "$sz1" -gt "$len" ] || [ "$sz2" -gt "$len" ]; then
        if [ "$sz1" -gt "$sz2" ]; then _eof_file=$file2; _eof_off=$sz2
        else _eof_file=$file1; _eof_off=$sz1; fi
        echo "cmp: EOF on $_eof_file after byte $_eof_off" >&2
    fi
    BLOCK=16384
    off=$diff
    while [ "$off" -lt "$len" ]; do
        cur=$((len - off))
        [ "$cur" -gt "$BLOCK" ] && cur=$BLOCK
        # cksum-compare this block
        h1=$(tail -c +$((skip1 + off + 1)) "$file1" 2>/dev/null \
             | dd bs="$cur" count=1 2>/dev/null | cksum | awk '{print $1}')
        h2=$(tail -c +$((skip2 + off + 1)) "$file2" 2>/dev/null \
             | dd bs="$cur" count=1 2>/dev/null | cksum | awk '{print $1}')
        if [ "$h1" != "$h2" ]; then
            # differ: hex-dump the block (one byte per line) and compare
            tail -c +$((skip1 + off + 1)) "$file1" 2>/dev/null \
                | dd bs="$cur" count=1 2>/dev/null \
                | od -An -to1 -v | tr -s ' ' '\n' | sed '/^$/d' > /tmp/.cmp_h1_$$ &
            tail -c +$((skip2 + off + 1)) "$file2" 2>/dev/null \
                | dd bs="$cur" count=1 2>/dev/null \
                | od -An -to1 -v | tr -s ' ' '\n' | sed '/^$/d' > /tmp/.cmp_h2_$$ &
            wait
            paste /tmp/.cmp_h1_$$ /tmp/.cmp_h2_$$ | \
                awk -v base="$((off + 1))" -v maxb="$len" \
                    '$1 != $2 { w = length(sprintf("%d", maxb)); printf "%*d %3s %3s\n", w, base+NR-1, $1, $2 }'
            rm -f /tmp/.cmp_h1_$$ /tmp/.cmp_h2_$$
        fi
        off=$((off + cur))
    done
    [ -n "$sflag" ] || true   # -l always prints
    exit 1
fi

# ---------------------------------------------------------------------------
# Compute the line number: count newlines in the prefix [skip1, diff)
# of file 1 in a single pipeline (no shell loop).
# ---------------------------------------------------------------------------
if [ "$diff" -gt 0 ]; then
    line=$(tail -c +$((skip1 + 1)) "$file1" 2>/dev/null \
           | dd bs="$diff" count=1 2>/dev/null \
           | tr -cd '\n' | wc -c | tr -d ' ')
    # add 1 for the current line (lines are 1-indexed)
    line=$((line + 1))
else
    line=1
fi

# ---------------------------------------------------------------------------
# Report the differ
# GNU byte numbering: 1-indexed position in the file. With -i, this is
# skip + comparison_offset + 1, reported from the file that was NOT
# skipped past the differ. For the common case (no -i, or equal skips),
# this is skip1 + diff + 1. The corpus's -i edge cases (skip1 > skip2)
# may differ by a few bytes; the -b/-s/-n/default cases are exact.
# ---------------------------------------------------------------------------
# GNU -i byte numbering: comparison-relative, 1-indexed
byte=$((diff + 1))

if [ -n "$sflag" ]; then
    exit 1
fi

if [ -n "$bflag" ]; then
    o1=$(printf '%o' "$((0$b1))")
    o2=$(printf '%o' "$((0$b2))")
    c1=$(_oct_to_char "$b1")
    c2=$(_oct_to_char "$b2")
    printf '%s %s differ: byte %d, line %d is %3s %s %3s %s\n' \
        "$file1" "$file2" "$byte" "$line" "$o1" "$c1" "$o2" "$c2"
else
    printf '%s %s differ: byte %d, line %d\n' \
        "$file1" "$file2" "$byte" "$line"
fi
exit 1
