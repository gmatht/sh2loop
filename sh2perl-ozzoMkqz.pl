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
if ("x$1" eq xremove) {
    $main_exit_code = system('update-alternatives', '--remove', 'default.plymouth', '/usr/share/plymouth/themes/spinner/spinner.plymouth') >> 8;
    $main_exit_code = system('update-alternatives', '--remove', 'text.plymouth', '/usr/share/plymouth/themes/text.plymouth') >> 8;
}

exit $main_exit_code;
