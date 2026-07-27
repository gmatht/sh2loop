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

my $MAGIC_70 = 70;
my $MAGIC_20 = 20;
my $MAGIC_10 = 10;

$main_exit_code = system('.', './setup-vars') >> 8;
$CHILD_ERROR = 0;
my $returncode;
my @returncode;
my %returncode;
$returncode = $?;
$main_exit_code = system('.', './report-button') >> 8;

exit $main_exit_code;
