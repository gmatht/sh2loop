#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("1")] }, None)')) {
    say $1;
}
else {
    say join(" ", grep { length } split /\s+/msx, do { use File::Basename qw(dirname); my $dirname_output = dirname($1); $CHILD_ERROR = 0; $dirname_output; }) . q{ } . q{/} . q{ } . join(" ", grep { length } split /\s+/msx, do {
    do { my $output_0 = q{};
    my $output_printed_0;
    my $output_1 = q{};
    while (my $line = <>) {
        chomp $line;
        # basename doesn't support line-by-line processing
        # awk doesn't support line-by-line processing
    }
    $output_1; };
}) . q{ } . '.afm';
}
