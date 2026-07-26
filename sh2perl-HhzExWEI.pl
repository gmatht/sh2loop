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
if ("$_[0]" =~ /^purge$/msx) {
    if ( -e "/var/log/fontconfig.log" ) {
        if ( -d "/var/log/fontconfig.log" ) {
            carp "rm: carping: ", "/var/log/fontconfig.log",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/log/fontconfig.log" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/log/fontconfig.log",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ( -e "/var/cache/fontconfig" ) {
        if ( -d "/var/cache/fontconfig" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/var/cache/fontconfig", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/var/cache/fontconfig", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/var/cache/fontconfig" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/cache/fontconfig",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}

exit $main_exit_code;
