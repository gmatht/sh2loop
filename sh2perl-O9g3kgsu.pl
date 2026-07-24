#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $x;
my @x;
my %x;
$x = '42';
do { my $eval_input = "echo \"The answer is " . $x . "\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };

exit $main_exit_code;
