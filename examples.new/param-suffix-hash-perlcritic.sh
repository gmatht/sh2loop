#!/bin/bash
# Minimal reproduction: parameter expansion with # in suffix pattern.
# The # in s/#.*$//sr was incorrectly stripped as a Perl comment.
file="${file%%#*}"
echo "${file}"
