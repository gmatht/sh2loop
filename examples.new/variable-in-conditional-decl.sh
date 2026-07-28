#!/bin/bash
# Variable assigned inside if - should be hoisted outside
if test "x$1" = "xyes"; then
    result="yes"
    echo "$result"
fi
