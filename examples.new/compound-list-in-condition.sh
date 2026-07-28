#!/bin/bash
# Test: Compound list { ... } inside an if condition with &&
# This used to generate broken Perl from the { } block appearing
# inside a boolean condition, which confused PPI into reporting
# nested named subroutines.
f() {
    if test -f /tmp/a && { test -L /tmp/a || test ! -e /tmp/a; }; then
        echo "a"
    fi
}
