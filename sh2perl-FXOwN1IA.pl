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
if ("$1" ne upgrade) {
    $main_exit_code = system('update-alternatives', '--quiet', '--remove', 'cpp', '/usr/bin/cpp') >> 8;
}
$main_exit_code = system('dpkg-maintscript-helper', 'dir_to_symlink', '/usr/share/doc/cpp', 'cpp-aarch64-linux-gnu', '4:13.2.0-3', 'cpp', '--', "@ARGV") >> 8;

exit $main_exit_code;
