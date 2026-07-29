#!/bin/bash
# Functions defined inside another function body in shell script.
# When converted to Perl, these become top-level named subs.
# If the outer function contains complex constructs (like while getopts),
# brace imbalance in generated Perl can make the inner subs appear nested,
# triggering Perl::Critic's ProhibitNestedSubs.

outer() {
    while getopts 'ab:c' opt; do
        case $opt in
            a) echo "Option A" ;;
            b) echo "Option B: $OPTARG" ;;
            c) echo "Option C" ;;
        esac
    done
    inner1
    inner2
}

inner1() {
    echo "Inner function 1"
}

inner2() {
    echo "Inner function 2"
}

outer "$@"
