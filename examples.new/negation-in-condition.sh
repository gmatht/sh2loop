#!/bin/bash
# Test: Negation (!) of a command in an if condition.
# Previously, ! cmd would generate invalid Perl with a semicolon
# inside the condition: if (!(!(system(...) >> 8;)))
f() {
    if ! test -f /tmp/x; then
        echo "x does not exist"
    fi
}
