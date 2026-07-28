#!/bin/bash
# Keywords like 'if' appearing as command arguments
dd if=/dev/zero of=/tmp/keyword_in_arg_test bs=1k count=1
echo "done"
