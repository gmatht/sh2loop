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

my $br;
my @br;
my %br;
$br = "br0";
my $tap;
my @tap;
my %tap;
$tap = "tap0";
my $eth;
my @eth;
my %eth;
$eth = "eth0";
my $eth_ip;
my @eth_ip;
my %eth_ip;
$eth_ip = "192.168.8.4";
my $eth_netmask;
my @eth_netmask;
my %eth_netmask;
$eth_netmask = "255.255.255.0";
my $eth_broadcast;
my @eth_broadcast;
my %eth_broadcast;
$eth_broadcast = "192.168.8.255";
my $t;
for my $t ($tap) {
    $main_exit_code = system('openvpn', '--mktun', '--dev', $t) >> 8;
}
$main_exit_code = system('brctl', 'addbr', $br) >> 8;
$main_exit_code = system('brctl', 'addif', $br, $eth) >> 8;
for my $t ($tap) {
    $main_exit_code = system('brctl', 'addif', $br, $t) >> 8;
}
for my $t ($tap) {
    $main_exit_code = system('ifconfig', $t, '0.0.0.0', 'promisc', 'up') >> 8;
}
$main_exit_code = system('ifconfig', $eth, '0.0.0.0', 'promisc', 'up') >> 8;
$main_exit_code = system('ifconfig', $br, $eth_ip, 'netmask', $eth_netmask, 'broadcast', $eth_broadcast) >> 8;

exit $main_exit_code;
