#!/bin/bash
# Variable declared in conditional statement (if body)
if test "x$1" = "xyes"; then
    x=5
    echo "$x"
fi
