#!/bin/sh
# dirname "$0" — self-location; the directory must track argv0, not a
# baked-in constant (a basename-only argv0 yields ".").
echo "$(dirname "$0")"
