#!/bin/bash
# Regression test: pipeline command substitution inside a function.
# The generated Perl used to have unbalanced braces which made
# subsequent sub definitions appear nested (perlcritic violation).
foo() {
    result=$(grep '^model name' /proc/cpuinfo | head -1 | sed 's/.*: //')
    echo "$result"
}
bar() {
    echo "second function"
}
foo
