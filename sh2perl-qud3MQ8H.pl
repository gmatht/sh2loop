#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

if ("$ENV{reason}" =~ /^MEDIUM$/msx or "$ENV{reason}" =~ /^ARPCHECK$/msx or "$ENV{reason}" =~ /^ARPSEND$/msx or "$ENV{reason}" =~ /^NBI$/msx) {
} elsif ("$ENV{reason}" =~ /^PREINIT$/msx or "$ENV{reason}" =~ /^BOUND$/msx or "$ENV{reason}" =~ /^RENEW$/msx or "$ENV{reason}" =~ /^REBIND$/msx or "$ENV{reason}" =~ /^REBOOT$/msx or "$ENV{reason}" =~ /^STOP$/msx or "$ENV{reason}" =~ /^RELEASE$/msx) {
} elsif ("$ENV{reason}" =~ /^EXPIRE$/msx or "$ENV{reason}" =~ /^FAIL$/msx or "$ENV{reason}" =~ /^TIMEOUT$/msx) {
    if ((-x '/usr/sbin/avahi-autoipd')) {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('/usr/sbin/avahi-autoipd', '-w', q{D}, $interface) >> 8;
        };
    }
}

exit $main_exit_code;
