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

$__set_e = 1;
if (("$2" eq "hibernate" || "$2" eq "hybrid-sleep")) {
if ("$_[0]" =~ /^pre$/msx) {
                $main_exit_code = system('/usr/share/unattended-upgrades/unattended-upgrade-shutdown', '--stop-only') >> 8;
    }
}

exit $main_exit_code;
