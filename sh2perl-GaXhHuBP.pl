#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $dir = '/etc/openvpn';
$CHILD_ERROR = 0;
$main_exit_code = system('modprobe', 'tun') >> 8;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/proc/sys/net/ipv4/ip_forward'
      or die "Cannot access file: $OS_ERROR\n";
    my $tmp = do {
    say q{1};
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('openvpn', '--cd', $dir, '--daemon', '--config', 'vpn1.conf') >> 8;
$main_exit_code = system('openvpn', '--cd', $dir, '--daemon', '--config', 'vpn2.conf') >> 8;
$main_exit_code = system('openvpn', '--cd', $dir, '--daemon', '--config', 'vpn2.conf') >> 8;
