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
if ((upgrade ne "$1" || !($main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', '5.62-2') >> 8))) {
    $main_exit_code = system('dpkg-divert', '--add', '--package', 'libdigest-sha-perl', '--rename', '--divert', '/usr/bin/shasum.bundled', '/usr/bin/shasum') >> 8;
    $main_exit_code = system('dpkg-divert', '--add', '--package', 'libdigest-sha-perl', '--rename', '--divert', '/usr/share/man/man1/shasum.bundled.1.gz', '/usr/share/man/man1/shasum.1.gz') >> 8;
}
exit 0;

exit $main_exit_code;
