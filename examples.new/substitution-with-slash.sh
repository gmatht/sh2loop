#!/bin/bash
# Minimal reproduction: parameter expansion with prefix removal containing /
# The / in the pattern needs escaping in s///, and the # in %%pattern
# should not be treated as a comment.
file=${file#file://}
file=${file%%#*}
echo "${file}"
