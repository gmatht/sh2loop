#!/bin/bash
f() { local sz=$(wc -c < "$f"); local mw=$(echo a b c); local p="${2:-d}"; local ar=$((x + y)); local ec=$?; local z="lit $y"; echo "$sz $mw $p $ar $ec $z"; }; f
