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
if ("$1" eq "purge") {
if ( -e "/etc/cron.allow" ) {
        if ( -d "/etc/cron.allow" ) {
            carp "rm: carping: ", "/etc/cron.allow",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/cron.allow" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/cron.allow",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/etc/cron.deny" ) {
        if ( -d "/etc/cron.deny" ) {
            carp "rm: carping: ", "/etc/cron.deny",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/cron.deny" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/cron.deny",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}

exit $main_exit_code;
