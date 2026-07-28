#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$__set_e = 1;
if ( -e "/usr/share/python3/__pycache__" ) {
    if ( -d "/usr/share/python3/__pycache__" ) {
        my $err;
        require File::Path;
        File::Path::remove_tree("/usr/share/python3/__pycache__", {error => \$err});
        if (@{$err}) {
            carp "rm: carping: could not remove ", "/usr/share/python3/__pycache__", ": $err->[0]\n";
        }
        else {
                    }
    }
    else {
        if ( unlink "/usr/share/python3/__pycache__" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "/usr/share/python3/__pycache__",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "/usr/share/python3/debpython/__pycache__" ) {
    if ( -d "/usr/share/python3/debpython/__pycache__" ) {
        my $err;
        require File::Path;
        File::Path::remove_tree("/usr/share/python3/debpython/__pycache__", {error => \$err});
        if (@{$err}) {
            carp "rm: carping: could not remove ", "/usr/share/python3/debpython/__pycache__", ": $err->[0]\n";
        }
        else {
                    }
    }
    else {
        if ( unlink "/usr/share/python3/debpython/__pycache__" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "/usr/share/python3/debpython/__pycache__",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}

exit $main_exit_code;
