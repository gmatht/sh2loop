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

my $SNAP_COMMON;
my @SNAP_COMMON;
my %SNAP_COMMON;
my $label;
my @label;
my %label;

$__set_e = 1;
# set u not implemented
if ((-d '/sys/kernel/security/apparmor')) {
    $label = (do { my $_chomp_temp = do { my @_qx_cmd = ("cat /proc/self/attr/current 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if (("$label" ne "unconfined" && "${label##*(unconfined)}" ne q{})) {
# Builtin command 'exec' not implemented
    }
}
$ENV{SNAP_CURRENT} = '';
my $LIB_ARCH;
my @LIB_ARCH;
my %LIB_ARCH;
$LIB_ARCH = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'readlink', '-f', ($ENV{SNAP_CURRENT} // q{}), '/lib/*-linux-gnu*/');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
$ENV{ARCH} = '';
$ENV{LD_LIBRARY_PATH} = '';
$ENV{PATH} = '';
$ENV{LXD_DIR} = '';
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('.', ($ENV{SNAP} // q{}) . "/commands/setup-zfs") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $LXD;
my @LXD;
my %LXD;
$LXD = "lxd";
if ((-x "${SNAP_COMMON}/lxd.debug")) {
    $LXD = ${SNAP_COMMON} . "/lxd.debug";
}
# Builtin command 'exec' not implemented

exit $main_exit_code;
