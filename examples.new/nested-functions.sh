#!/bin/sh
# Demonstrate: multiple top-level function definitions in the same file.
# When the first function body contains a pipeline, the generator may
# fail to close the sub before the next function → "Nested named subroutine".
# Usage: timeout 10 sh2perl -i nested-functions.sh 2>/dev/null | perlcritic
first() {
    x=$(echo foo | tr a-z A-Z)
    echo "$x"
}
second() {
    y=$(echo bar | tr a-z A-Z)
    echo "$y"
}
