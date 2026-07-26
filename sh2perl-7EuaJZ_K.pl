#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

print "Testing complex brace expansion...\n";
print join(q[ ], ('a' . '1' . 'x', 'a' . '1' . 'y', 'a' . '1' . 'z', 'a' . '2' . 'x', 'a' . '2' . 'y', 'a' . '2' . 'z', 'a' . '3' . 'x', 'a' . '3' . 'y', 'a' . '3' . 'z', 'b' . '1' . 'x', 'b' . '1' . 'y', 'b' . '1' . 'z', 'b' . '2' . 'x', 'b' . '2' . 'y', 'b' . '2' . 'z', 'b' . '3' . 'x', 'b' . '3' . 'y', 'b' . '3' . 'z', 'c' . '1' . 'x', 'c' . '1' . 'y', 'c' . '1' . 'z', 'c' . '2' . 'x', 'c' . '2' . 'y', 'c' . '2' . 'z', 'c' . '3' . 'x', 'c' . '3' . 'y', 'c' . '3' . 'z')) . "\n";
$CHILD_ERROR = 0;

exit $main_exit_code;
