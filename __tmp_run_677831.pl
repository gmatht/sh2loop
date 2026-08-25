#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use IPC::Open3;
my $main_exit_code = 0;
our $CHILD_ERROR = 0;
my $var;
my @array;
my $index;
my $result = int( (defined $var && $var ne q{} ? $var : 0) + (defined $array[(defined $index && $index ne q{} ? $index : 0)] && $array[(defined $index && $index ne q{} ? $index : 0)] ne q{} ? $array[(defined $index && $index ne q{} ? $index : 0)] : 0) );
print "Eval result: ${result}\n";
$CHILD_ERROR = 0;
