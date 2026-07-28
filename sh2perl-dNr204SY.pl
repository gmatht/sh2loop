#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $DAEMON_CONF;
my $DPKG_ROOT;

$__set_e = 1;
$main_exit_code = system(':', $DPKG_ROOT=) >> 8;
my $_dh_action;
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if (("${DPKG_ROOT:-}" eq q{} && (-x "/etc/init.d/hostapd"))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('update-rc.d', 'hostapd', 'defaults') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ("$2" ne q{}) {
            $_dh_action = 'restart';
}
        else {
            $_dh_action = 'start';
        }
                $main_exit_code = system('invoke-rc.d', "--skip-" . "sys" . "tem" . "d-native", 'hostapd', $_dh_action) >> 8;
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
;
    }
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'hostapd.service') >> 8;
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
if (!(system('deb-systemd-helper', '--quiet', 'was-enabled', 'hostapd.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'hostapd.service') >> 8;
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
    else {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'hostapd.service') >> 8;
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
            $main_exit_code = system('deb-systemd-invoke', $_dh_action, 'hostapd.service') >> 8;
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
if (((((-d '/run/systemd/system') && !(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', "sys" . "tem" . "ctl") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) && "$1" eq configure) && "$DPKG_ROOT" eq q{})) {
    $DAEMON_CONF = q{};
    $main_exit_code = system('.', '/etc/default/hostapd') >> 8;
if ((("$DAEMON_CONF" eq q{} && (!-r /etc/hostapd/hostapd.conf)) && !(!($main_exit_code = system('systemctl', '--quiet', 'is-active', 'hostapd.service') >> 8;)))) {
        $main_exit_code = system('systemctl', 'mask', 'hostapd.service') >> 8;
    }
}
exit 0;
