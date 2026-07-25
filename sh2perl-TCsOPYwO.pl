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

my $label;
my @label;
my %label;
my $SYSTEMD_OVERRIDE_DIR;
my @SYSTEMD_OVERRIDE_DIR;
my %SYSTEMD_OVERRIDE_DIR;
my $SYSCTL_OVERRIDE_DIR;
my @SYSCTL_OVERRIDE_DIR;
my %SYSCTL_OVERRIDE_DIR;

$__set_e = 1;
# set u not implemented
if ((-d '/sys/kernel/security/apparmor')) {
    $label = (do { my $_chomp_temp = do { my @_qx_cmd = ("cat /proc/self/attr/current 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if (("$label" ne "unconfined" && "${label##*(unconfined)}" ne q{})) {
# Builtin command 'exec' not implemented
    }
}
my $path;
for my $path (($ENV{SNAP_COMMON} // q{}) . "/ns/shmounts", ($ENV{SNAP_COMMON} // q{}) . "/ns/mntns", ($ENV{SNAP_COMMON} // q{}) . "/ns", ($ENV{SNAP_COMMON} // q{}) . "/var/lib/lxcfs/", ($ENV{SNAP_COMMON} // q{}) . "/shmounts") {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('nsenter', '-t', q{1}, '-m', 'umount', '-l', ${path}) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('nsenter', '-t', q{1}, '-m', "sys" . "tem" . "ctl", 'stop', 'snap.lxd.workaround') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
    1;
}
$SYSTEMD_OVERRIDE_DIR = "/var/lib/snapd/hostfs/run/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/snap.lxd.daemon.service.d";
if ((-e "${SYSTEMD_OVERRIDE_DIR}/lxd-shutdown.conf")) {
    if ( -e "${SYSTEMD_OVERRIDE_DIR} . "/lxd-shutdown.conf"" ) {
        if ( -d "${SYSTEMD_OVERRIDE_DIR} . "/lxd-shutdown.conf"" ) {
            croak "rm: ", ${SYSTEMD_OVERRIDE_DIR} . "/lxd-shutdown.conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${SYSTEMD_OVERRIDE_DIR} . "/lxd-shutdown.conf"" ) {
                            }
            else {
                croak "rm: cannot remove ", ${SYSTEMD_OVERRIDE_DIR} . "/lxd-shutdown.conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", ${SYSTEMD_OVERRIDE_DIR} . "/lxd-shutdown.conf", ": No such file or directory\n";
    }
    if ($CHILD_ERROR != 0) {
        1;
    }
rmdir (${SYSTEMD_OVERRIDE_DIR}) or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        $main_exit_code = system('nsenter', '-t', q{1}, '-m', "sys" . "tem" . "ctl", 'daemon-reload') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
}
$SYSCTL_OVERRIDE_DIR = "/var/lib/snapd/hostfs/run/sysctl.d";
if ((-e "${SYSCTL_OVERRIDE_DIR}/zz-lxd.conf")) {
    if ( -e "${SYSCTL_OVERRIDE_DIR} . "/zz-lxd.conf"" ) {
        if ( -d "${SYSCTL_OVERRIDE_DIR} . "/zz-lxd.conf"" ) {
            croak "rm: ", ${SYSCTL_OVERRIDE_DIR} . "/zz-lxd.conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${SYSCTL_OVERRIDE_DIR} . "/zz-lxd.conf"" ) {
                            }
            else {
                croak "rm: cannot remove ", ${SYSCTL_OVERRIDE_DIR} . "/zz-lxd.conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", ${SYSCTL_OVERRIDE_DIR} . "/zz-lxd.conf", ": No such file or directory\n";
    }
    if ($CHILD_ERROR != 0) {
        1;
    }
rmdir (${SYSCTL_OVERRIDE_DIR}) or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        $main_exit_code = system('nsenter', '-t', q{1}, '-m', "sys" . "tem" . "ctl", 'restart', "sys" . "tem" . "d-sysctl.service") >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
}
exit 0;

exit $main_exit_code;
