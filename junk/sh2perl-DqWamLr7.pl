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

my $IF_IP_RP_FILTER;
my @IF_IP_RP_FILTER;
my %IF_IP_RP_FILTER;
my $IF_IP_PROXY_ARP;
my @IF_IP_PROXY_ARP;
my %IF_IP_PROXY_ARP;
my $IFACE;
my @IFACE;
my %IFACE;

if ((-d "/proc/sys/net/ipv4/conf/$IFACE")) {
if ("$IF_IP_PROXY_ARP" ne q{}) {
if (($IF_IP_PROXY_ARP == 1)) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "/proc/sys/net/ipv4/conf/$IFACE/proxy_arp"
      or die "Cannot open file: $OS_ERROR\n";
                print q{1} . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
}
        else {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "/proc/sys/net/ipv4/conf/$IFACE/proxy_arp"
      or die "Cannot open file: $OS_ERROR\n";
                print q{0} . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
if ("$IF_IP_RP_FILTER" ne q{}) {
if (($IF_IP_RP_FILTER == 0)) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "/proc/sys/net/ipv4/conf/$IFACE/rp_filter"
      or die "Cannot open file: $OS_ERROR\n";
                print q{0} . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
}
        else {
            if (($IF_IP_RP_FILTER == 2)) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', "/proc/sys/net/ipv4/conf/$IFACE/rp_filter"
      or die "Cannot open file: $OS_ERROR\n";
                    print q{2} . "\n";
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
}
            else {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', "/proc/sys/net/ipv4/conf/$IFACE/rp_filter"
      or die "Cannot open file: $OS_ERROR\n";
                    print q{1} . "\n";
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
        }
    }
}

exit $main_exit_code;
