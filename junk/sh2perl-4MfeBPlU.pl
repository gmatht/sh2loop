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

$__set_e = 1;
if ((-r '/lib/cryptsetup/cryptdisks-functions')) {
    $main_exit_code = system('.', '/lib/cryptsetup/cryptdisks-functions') >> 8;
}
else {
exit 0;
}
my $INITSTATE;
my @INITSTATE;
my %INITSTATE;
$INITSTATE = "early";
my $DEFAULT_LOUD;
my @DEFAULT_LOUD;
my %DEFAULT_LOUD;
$DEFAULT_LOUD = "";
if ("$ENV{CRYPTDISKS_ENABLE}" =~ /^\[Nn\].*$/msx) {
    exit 0;
}
if ("$_[0]" =~ /^start$/msx) {
        $main_exit_code = system('bash', 'do_start') >> 8;
} elsif ("$_[0]" =~ /^stop$/msx) {
        $main_exit_code = system('bash', 'do_stop') >> 8;
} elsif ("$_[0]" =~ /^restart$/msx or "$_[0]" =~ /^reload$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $main_exit_code = system('bash', 'do_stop') >> 8;
        $main_exit_code = system('bash', 'do_start') >> 8;
} elsif ("$_[0]" =~ /^force-start$/msx) {
        my $FORCE_START;
    my @FORCE_START;
    my %FORCE_START;
    $FORCE_START = "yes";
        $main_exit_code = system('bash', 'do_start') >> 8;
} elsif (1) {
        print "Usage: cryptdisks-early {start|stop|restart|reload|force-reload|force-start}\n";
    exit 1;
}

exit $main_exit_code;
