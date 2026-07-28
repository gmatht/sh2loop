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

my $DEFAULT;
my @DEFAULT;
my %DEFAULT;
my $ENABLED;
my @ENABLED;
my %ENABLED;

$__set_e = 1;
if (!((!-d /run/systemd/system))) {
    exit 0;
}
$DEFAULT = '/etc/default/sysstat';
$ENABLED = 'false';
if (!((!-r "$DEFAULT"))) {
        $main_exit_code = system('.', "$DEFAULT") >> 8;
}
if (!("$ENABLED" eq "true")) {
    exit 0;
}
# Builtin command 'exec' not implemented

exit $main_exit_code;
