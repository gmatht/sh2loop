#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use IPC::Open3;
my $main_exit_code = 0;
my $output = '';
our $CHILD_ERROR = 0;
$0 = 'parse-dollar-keyword-var.sh';
my @_cmd_0 = ('bash', 'exec=/usr/sbin/dkms');
$main_exit_code = $CHILD_ERROR = system(@_cmd_0) >> 8;
my $prog = basename(($ENV{exec} // q{}));
$CHILD_ERROR = ((-f $exec)) ? 0 : 1;
if ($CHILD_ERROR != 0) {
    exit q{0};
}
printf("%s=[%s]\n", 'prog', (defined ${prog} && ${prog} ne q{} ? ${prog} : ''));
$CHILD_ERROR = 0;

exit $main_exit_code;
