#!/bin/bash
# Demonstrate a function defined inside another function.
# sh2perl converts this to Perl. The inner function 'helper' may appear
# as a nested named sub in the generated Perl, triggering Perl::Critic's
# ProhibitNestedSubs policy.

outer_func() {
    echo "Outer function running"
    helper
}

helper() {
    echo "Helper function running"
}

outer_func
