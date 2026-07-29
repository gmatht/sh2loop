#!/bin/bash
# Minimal reproduction: grep with a pattern that should not use {pattern}
# in the generated Perl (which triggers perlcritic ProhibitMutatingListFunctions).
# The generated code should use /pattern/, not {pattern}.
result=$(grep -q 'CONFIG_CC_IS_CLANG=y' /dev/null 2>/dev/null || true)
