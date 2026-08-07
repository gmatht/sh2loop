#!/bin/sh
# The self-locating-script idiom: resolve the script's own directory from
# argv0. The result must track argv0 (a basename-only argv0 yields "." →
# the caller's cwd), never a baked-in constant.
echo "$(cd "$(dirname "$0")" && pwd)"
