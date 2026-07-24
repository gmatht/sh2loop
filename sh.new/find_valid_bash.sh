#!/bin/bash
#==============================================================================
# find_valid_bash.sh
#
# Finds all regular files (except those in sh.new/), tests if they are valid
# bash scripts with 'bash -n' (syntax check), and if so:
#   1. Appends the file path to valid.txt.new
#   2. Copies the script to sh.new/ (if not already there)
#
# Usage: find_valid_bash.sh [search_root]
#   If search_root is omitted, searches from the current directory.
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" || echo "$0")")" && pwd)"
SEARCH_ROOT="${1:-$SCRIPT_DIR}"
VALID_NEW="$SCRIPT_DIR/valid.txt.new"
SH_NEW_DIR="$SCRIPT_DIR/sh.new"

# Create output directory
mkdir -p "$SH_NEW_DIR"

# Truncate valid.txt.new (start fresh)
> "$VALID_NEW"

echo "Searching for regular files under: $SEARCH_ROOT"
echo "(excluding $SH_NEW_DIR)"
echo "Writing valid paths to: $VALID_NEW"
echo "Copying valid scripts to: $SH_NEW_DIR/"
echo "============================================================"

count_found=0
count_valid=0

# We need to avoid subshell issues, so read from find with process substitution
while IFS= read -r -d '' file; do
    count_found=$((count_found + 1))

    # Progress indicator every 5000 files
    if [ $((count_found % 5000)) -eq 0 ]; then
        echo "  ... found $count_found files, $count_valid valid (last: $file)"
    fi

    # Quick pre-check: must start with #! and contain bash or sh
    read -r first_line < "$file" 2>/dev/null || continue
    case "$first_line" in
        '#!/bin/bash'*|'#!/bin/sh'*|'#!/usr/bin/bash'*|'#!/usr/bin/sh'*|'#!/usr/bin/env bash'*|'#!/usr/bin/env sh'*) ;;
        *) continue ;;  # Not a bash/sh script
    esac

    # Full syntax check with bash -n
    if bash -n "$file" 2>/dev/null; then
        echo "$file" >> "$VALID_NEW"
        count_valid=$((count_valid + 1))

        # Copy to sh.new/ if not already there (basename collisions skipped)
        dest="$SH_NEW_DIR/$(basename "$file")"
        if [ ! -e "$dest" ]; then
            cp -- "$file" "$dest"
        fi
    fi
done < <(find "$SEARCH_ROOT" -path "$SH_NEW_DIR" -prune -o -type f -print0 2>/dev/null)

echo "============================================================"
echo "Done. Found $count_found regular files, $count_valid are valid bash scripts."
echo "Results in: $VALID_NEW"
echo "Scripts copied to: $SH_NEW_DIR/"
