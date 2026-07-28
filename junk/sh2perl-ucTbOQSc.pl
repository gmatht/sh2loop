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
# set u not implemented
if ($arg1 =~ /^purge$/msx) {
    if ( -e "v" ) {
        if ( -d "v" ) {
            carp "rm: carping: ", "v",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "v" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "v",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/etc/adduser.conf" ) {
        if ( -d "/etc/adduser.conf" ) {
            carp "rm: carping: ", "/etc/adduser.conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/adduser.conf" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/adduser.conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/etc/adduser.conf.dpkg-save" ) {
        if ( -d "/etc/adduser.conf.dpkg-save" ) {
            carp "rm: carping: ", "/etc/adduser.conf.dpkg-save",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/adduser.conf.dpkg-save" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/adduser.conf.dpkg-save",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/etc/adduser.conf.update-old" ) {
        if ( -d "/etc/adduser.conf.update-old" ) {
            carp "rm: carping: ", "/etc/adduser.conf.update-old",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/adduser.conf.update-old" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/adduser.conf.update-old",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
# set +eu not implemented

exit $main_exit_code;
