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
if ((-d '/run/systemd/system')) {
exit 0;
}

sub check_power {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'on_ac_power') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
if (!(        $main_exit_code = system('bash', 'on_ac_power') >> 8)) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            if (($? == 1)) {
return q{1};
            }
        }
    }
return q{0};
    return;
}

sub random_sleep {
    my $RandomSleep;
    my @RandomSleep;
    my %RandomSleep;
    $RandomSleep = '1800';
do { my $eval_input = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'apt-config', 'shell', 'RandomSleep', 'APT::Periodic::RandomSleep');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
if (($RandomSleep == 0)) {
return;
    }
if ("$RANDOM" eq q{}) {
        my $RANDOM;
        my @RANDOM;
        my %RANDOM;
        my $dd;
        my $dev;
        my $urandom;
        my $bs;
        my $count;
        my $null;
        my $cksum;
        my $cut;
        my $d;
        my $f1;
        $RANDOM = eval { int( do { chomp(my $_r = qx'dd if=/dev/urandom bs=2 count=1 2> /dev/null | cksum | cut -d'\'' '\'' -f1'); $_r; } % 32767 ) } // "";
    }
    my $TIME;
    my @TIME;
    my %TIME;
    $TIME = eval { int($RANDOM % $RandomSleep) } // "";
require Time::HiRes; Time::HiRes::sleep($TIME);
    return;
}
random_sleep();
check_power();
if ($CHILD_ERROR != 0) {
    exit 0;
}
# Builtin command 'exec' not implemented

exit $main_exit_code;
