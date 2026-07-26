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

$main_exit_code = system('.', './setup-vars') >> 8;
$main_exit_code = system('.', './setup-tempfile') >> 8;
do {
local *STDERR;
open STDERR, '>', $tempfile or croak "Cannot open file: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
my $returncode;
my @returncode;
my %returncode;
$returncode = $?;
$main_exit_code = system('.', './report-tempfile') >> 8;

exit $main_exit_code;
