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
# set uo not implemented
# set pipefail not implemented
print "== Escape sequences ==\n";
print 'bell' . "\n";
$CHILD_ERROR = 0;
print 'backspace' . "\n";
$CHILD_ERROR = 0;
print 'formfeed' . "\n";
$CHILD_ERROR = 0;
print "newline\n" . "\n";
$CHILD_ERROR = 0;
print "carriage\rreturn\n";
print "tab\tseparated\n";
print 'verticaltab' . "\n";
$CHILD_ERROR = 0;

exit $main_exit_code;
