#!/bin/sh
# Pipeline with backslash continuation spanning multiple lines.
# The first line must NOT be used alone inside qx{} because it
# would end with '\' and escape the closing '}' of qx{...\}.
echo "hello world" \
    | tr a-z A-Z
