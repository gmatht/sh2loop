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

my $COMMIT_MSG_FILE;
my @COMMIT_MSG_FILE;
my %COMMIT_MSG_FILE;
$COMMIT_MSG_FILE = $1;
my $COMMIT_SOURCE;
my @COMMIT_SOURCE;
my %COMMIT_SOURCE;
$COMMIT_SOURCE = $2;
my $SHA1;
my @SHA1;
my %SHA1;
$SHA1 = $3;
$main_exit_code = system('/usr/bin/perl', '-i.bak', '-ne', 'print unless(m/^. Please enter the commit message/..m/^#$/)', "$COMMIT_MSG_FILE") >> 8;

exit $main_exit_code;
