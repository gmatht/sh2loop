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

my $MAGIC_4755 = 4_755;

$__set_e = 1;
$main_exit_code = system('/bin/chown', 'root.root', '/usr/bin/gpio') >> 8;
$main_exit_code = system('/bin/chmod', '4755', '/usr/bin/gpio') >> 8;
$main_exit_code = system('bash', '/sbin/ldconfig') >> 8;

exit $main_exit_code;
