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

$main_exit_code = system('.', 'git-sh-setup') >> 8;
my $commitmsg;
my @commitmsg;
my %commitmsg;
$commitmsg = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'git', 'rev-parse', '--git-path', 'hooks/commit-msg');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
if (do {
$main_exit_code = system('test', '-x', "$commitmsg") >> 8;
    $CHILD_ERROR == 0
}) {
    # Builtin command 'exec' not implemented
}
$main_exit_code = system('bash', ':') >> 8;

exit $main_exit_code;
