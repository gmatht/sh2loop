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
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
$main_exit_code = system('db_input', 'low', 'iproute2/setcaps') >> 8;
if ($CHILD_ERROR != 0) {
    1;
}
$main_exit_code = system('bash', 'db_go') >> 8;
exit 0;

exit $main_exit_code;
