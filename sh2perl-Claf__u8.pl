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
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/default/hdparm', "9.48\\+ds-1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/hdparm', "9.48\\+ds-1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apm/event.d/20hdparm', "9.58\\+ds-3\\~", '--', "@ARGV") >> 8;

exit $main_exit_code;
