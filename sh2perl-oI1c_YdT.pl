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
if (((!-L /usr/share/doc/debconf-utils) && (-e '/usr/share/doc/debconf-utils'))) {
rmdir ('/usr/share/doc/debconf-utils') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink q{f}, '/usr/share/doc/debconf-utils' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}

exit $main_exit_code;
