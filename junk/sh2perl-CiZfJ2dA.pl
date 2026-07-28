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

$__set_e = 1;
# set uo not implemented
# set pipefail not implemented
print "== Advanced brace expansion ==\n";
print join(q[ ], ('a' . '1', 'a' . '2', 'a' . '3', 'b' . '1', 'b' . '2', 'b' . '3', 'c' . '1', 'c' . '2', 'c' . '3')) . "\n";
$CHILD_ERROR = 0;
print "1 3 5 7 9\n";
print "a d g j m p s v y\n";

exit $main_exit_code;
