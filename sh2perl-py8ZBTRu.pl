#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;

sub update_hwdb {
        $main_exit_code = system('systemd-hwdb', '--usr', 'update') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
;
    return;
}
if ("$_[0]" eq 'configure') {
        update_hwdb();
    if ((!(system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "254.3-1~") >> 8) && (!-f /etc/init.d/udev))) {
                $main_exit_code = system('update-rc.d', 'udev', 'remove') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
} elsif ("$_[0]" eq 'triggered') {
        update_hwdb();
    exit 0;
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
    $main_exit_code = system('systemd-sysusers', (defined ($ENV{DPKG_ROOT} // q{}) && ($ENV{DPKG_ROOT} // q{}) ne q{} ? ($ENV{DPKG_ROOT} // q{}) : '--root="$DPKG_ROOT"'), 'debian-udev.conf') >> 8;
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "$(command -v systemd-tmpfiles)")) {
                $main_exit_code = system('systemd-tmpfiles', (defined ($ENV{DPKG_ROOT} // q{}) && ($ENV{DPKG_ROOT} // q{}) ne q{} ? ($ENV{DPKG_ROOT} // q{}) : '--root="$DPKG_ROOT"'), '--create', 'static-nodes-permissions.conf') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/udev', "254.3-1\\~", '--', "\@ARGV") >> 8;
my $_dh_action;
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-d '/run/systemd/system')) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('systemctl', "--" . "sys" . "tem", 'daemon-reload') >> 8;
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
;
if ("$2" ne q{}) {
            $_dh_action = 'restart';
}
        else {
            $_dh_action = 'start';
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-invoke', $_dh_action, "sys" . "tem" . "d-udevd.service") >> 8;
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
;
    }
}
