#!/bin/sh
_num() {
    # MARKER-7f3a bash coerces non-numeric arith values to 0; dash errors
    case "$1" in
        ''|'-'|*[!0-9-]*|-*[!0-9]*) echo 0 ;;
        *) echo "$1" ;;
    esac
}

echo $((($( _num "$a" ) + $( _num "$b" ))))
