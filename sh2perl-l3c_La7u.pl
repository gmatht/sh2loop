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

if ((!-e /usr/lib/ssl)) {
    print 'Linking' . q{ } . '/usr/lib/ssl' . q{ } . 'to' . q{ } . '/etc/ssl' . "\n";
    $CHILD_ERROR = 0;
symlink q{f}, '/usr/lib/ssl' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}

exit $main_exit_code;
