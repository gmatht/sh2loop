#!/bin/bash
# A function using while getopts can produce a multi-statement while
# condition in generated Perl.  This can cause brace imbalance that
# makes later top-level functions appear nested, triggering
# Perl::Critic's ProhibitNestedSubs.

parse_opts() {
    while getopts 'ab:c' opt; do
        case $opt in
            a) echo "Option A" ;;
            b) echo "Option B: $OPTARG" ;;
            c) echo "Option C" ;;
        esac
    done
}

another_func() {
    echo "This is another top-level function"
}

third_func() {
    echo "This is a third top-level function"
}

parse_opts "$@"
