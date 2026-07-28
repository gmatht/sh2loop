#!/bin/sh
# Demonstrate: echo | tr pipeline inside command substitution inside a function.
# Previously generated unbalanced Perl braces → perlcritic violation.
# Usage: timeout 10 sh2perl -i echo-pipe-tr-cmdsub.sh | perlcritic
get_bool() {
    value=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
    for yes in "true" "1" "yes" "on"; do
        if [ "${value}" = "${yes}" ]; then
            echo "true"
            return
        fi
    done
}
