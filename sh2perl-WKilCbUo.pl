#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $DPKG_ROOT;

$__set_e = 1;
if (((-d '/run/systemd/system') && "$1" eq remove)) {
        $main_exit_code = system('systemctl', 'stop', 'syslog.socket') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
;
}
if ((("${DPKG_ROOT:-}" eq q{} && "$1" eq remove) && (-d '/run/systemd/system'))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-invoke', 'stop', 'dmesg.service', 'rsyslog.service') >> 8;
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
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/default/rsyslog', "8.1905.0-4\\~", '--', "\@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/rsyslog', "8.2110.0-2\\~", '--', "\@ARGV") >> 8;
