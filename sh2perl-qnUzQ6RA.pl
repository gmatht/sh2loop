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
if ((scalar(@ARGV) < 1)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "usage: $PROGRAM_NAME <name>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "reads /etc/crypttab and stops the mapping corresponding to <name>\n";
    };
exit 1;
}
$main_exit_code = system('.', '/lib/cryptsetup/cryptdisks-functions') >> 8;
my $INITSTATE;
my @INITSTATE;
my %INITSTATE;
$INITSTATE = "manual";
my $DEFAULT_LOUD;
my @DEFAULT_LOUD;
my %DEFAULT_LOUD;
$DEFAULT_LOUD = "yes";
if ((qx'id -u' != 0)) {
    $main_exit_code = system('log_warning_msg', "$PROGRAM_NAME needs root privileges") >> 8;
exit 1;
}
$main_exit_code = system('log_action_begin_msg', "Stopping crypto disk") >> 8;
my $rv;
my @rv;
my %rv;
$rv = q{0};
my $name;
for my $name (@ARGV) {
        $main_exit_code = system('remove_mapping', "$name") >> 8;
    if ($CHILD_ERROR != 0) {
                $rv = $?;
    }
}
$main_exit_code = system('log_action_end_msg', $rv) >> 8;


exit $main_exit_code;
