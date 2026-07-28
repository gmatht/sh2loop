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

my $quiet;
my @quiet;
my %quiet;

my $PREREQS;
my @PREREQS;
my %PREREQS;
$PREREQS = "";

sub prereqs {
    print $PREREQS;
if ( !( ($PREREQS) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}
if ("$_[0]" =~ /^prereqs$/msx) {
        prereqs();
    exit 0;
}
if ((-w '/sys/kernel/uevent_helper')) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/sys/kernel/uevent_helper'
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if ("${quiet:-n}" eq "y") {
    my $log_level;
    my @log_level;
    my %log_level;
    $log_level = 'notice';
}
else {
    $log_level = 'info';
}
my $SYSTEMD_LOG_LEVEL;
my @SYSTEMD_LOG_LEVEL;
my %SYSTEMD_LOG_LEVEL;
$SYSTEMD_LOG_LEVEL = $log_level;
$main_exit_code = system('/usr/lib/systemd/systemd-udevd', '--daemon', '--resolve-names=never') >> 8;
$main_exit_code = system('udevadm', 'trigger', "--type=sub" . "sys" . "tem" . "s", '--action=add') >> 8;
$main_exit_code = system('udevadm', 'trigger', '--type=devices', '--action=add') >> 8;
$main_exit_code = system('udevadm', 'settle') >> 8;
if ($CHILD_ERROR != 0) {
    1;
}

exit $main_exit_code;
