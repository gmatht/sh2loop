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

my $CTRL;
my @CTRL;
my %CTRL;
my $IFPLUGD_IFACE;
my @IFPLUGD_IFACE;
my %IFPLUGD_IFACE;
my $IFACE;
my @IFACE;
my %IFACE;

my $PATH;
my @PATH;
my %PATH;
$PATH = '/sbin:/usr/sbin:/bin:/usr/bin';
if ((!-x /usr/sbin/wpa_action)) {
exit 0;
}
$IFPLUGD_IFACE = $_[0];
if ($_[1] =~ /^up$/msx) {
        my $COMMAND;
    my @COMMAND;
    my %COMMAND;
    $COMMAND = 'disconnect';
} elsif ($_[1] =~ /^down$/msx) {
        $COMMAND = 'reconnect';
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$PROGRAM_NAME: unknown arguments: " . ${@};
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
for my $CTRL ('/run/wpa_supplicant/*') {
    if (!(( -S "${CTRL}"))) {
        next;    }
    $IFACE = (${CTRL} =~ s/^/run/wpa_supplicant///r =~ s/^/run/wpa_supplicant///r);
if ("${IFPLUGD_IFACE}" eq "${IFACE}") {
next;
    }
if (!(    $main_exit_code = system('wpa_action', ${IFACE}, 'check') >> 8)) {
        $main_exit_code = system('wpa_cli', '-i', ${IFACE}, ${COMMAND}) >> 8;
    }
}

exit $main_exit_code;
