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

my $apparmor_profile;
my @apparmor_profile;
my %apparmor_profile;
my $include_dir;
my @include_dir;
my %include_dir;

$apparmor_profile = "/etc/apparmor.d/usr.sbin.rsyslogd";
$include_dir = "/etc/apparmor.d/rsyslog.d";
if (!((-f "${apparmor_profile}"))) {
    exit 0;
}
if (!((-d "${include_dir}"))) {
    exit 0;
}
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    $main_exit_code = system('aa-status', '--enabled') >> 8;
};
if ($CHILD_ERROR != 0) {
    exit 0;
}
$main_exit_code = system('apparmor_parser', '-r', '-W', '-T', ${apparmor_profile}) >> 8;
if ($CHILD_ERROR != 0) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Failed to reload the " . ${apparmor_profile} . " apparmor profile, continuing anyway";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
}
exit 0;

exit $main_exit_code;
