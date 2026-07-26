#!/bin/bash
# declare with output redirect should not cause a parse error
declare -F foo >/dev/null && true
