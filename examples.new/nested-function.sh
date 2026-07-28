#!/bin/sh
# Verify nested functions use anonymous subs to avoid Perl::Critic
# "Nested named subroutine" violations.
outer() {
    inner() {
        echo "hello from inner"
    }
    inner
    inner2() {
        echo "hello from inner2"
    }
    inner2
}
outer
inner() {
    echo "global inner"
}
inner
