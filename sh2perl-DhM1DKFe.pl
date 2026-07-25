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

if ($1 eq q{}) {
    my $user;
    my @user;
    my %user;
    $user = 'root';
}
else {
    $user = $1;
}
$main_exit_code = system('sudo', 'sed', '-i', '/autologin-user=/d', '/etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf') >> 8;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>>', '/etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('sudo', 'echo', 'autologin-user', q{=}, $user) >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('sudo', 'sed', '-i', 's/root/anything/', '/etc/pam.d/lightdm-autologin') >> 8;

exit $main_exit_code;
