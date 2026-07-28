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


sub create_hosts_file {
if ((-e '/etc/hosts')) {
return q{0};
    }
open my $fh_cat, '>', '/etc/hosts' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "\t127.0.0.1\tlocalhost
\t::1\t\tlocalhost ip6-localhost ip6-loopback
\tff02::1\t\tip6-allnodes
\tff02::2\t\tip6-allrouters

";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub create_networks_file {
if ((-e '/etc/networks')) {
return q{0};
    }
open my $fh_cat, '>', '/etc/networks' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "\tdefault\t\t0.0.0.0
\tloopback\t127.0.0.0
\tlink-local\t169.254.0.0

";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub create_bindv6only_conf {
if ((-e '/etc/sysctl.d/bindv6only.conf')) {
return q{0};
    }
    if (!("$(uname -s)" eq "Linux")) {
        return q{0};    }
    if (!((-d '/etc/sysctl.d/'))) {
                use File::Path qw(make_path);
        my $err;
        if ( mkdir '/etc/sysctl.d/' ) {
            }
        else {
            croak "mkdir: cannot create directory " . '/etc/sysctl.d/' . ": File exists\n";
        }
    }
if ((("$2") && !(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "4.38") >> 8))) {
return q{0};
    }
open my $fh_cat, '>', '/etc/sysctl.d/bindv6only.conf' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "# This sysctl sets the default value of the IPV6_V6ONLY socket option.
#
# When disabled, IPv6 sockets will also be able to send and receive IPv4
# traffic with addresses in the form ::ffff:192.0.2.1 and daemons listening
# on IPv6 sockets will also accept IPv4 connections.
#
# When IPV6_V6ONLY is enabled, daemons interested in both IPv4 and IPv6
# connections must open two listening sockets.
# This is the default behaviour of almost all modern operating systems.

net.ipv6.bindv6only = 1
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}
if ("$_[0]" =~ /^configure$/msx) {
    if ("$2" eq q{}) {
        create_hosts_file();
        create_networks_file();
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postinst called with unknown argument '$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 1;
}

exit $main_exit_code;
