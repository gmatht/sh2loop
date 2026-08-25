#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use IPC::Open3;

my $main_exit_code = 0;
our $CHILD_ERROR = 0;
my $__argc = @ARGV;
my $ls_success = 0;
my $output = '';
my $__nocasematch = 0;

print "hi\n";
$main_exit_code = $CHILD_ERROR = 0;

exit $main_exit_code;
