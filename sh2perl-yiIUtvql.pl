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

my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if ("$_[0]" =~ /^remove$/msx or "$_[0]" =~ /^upgrade$/msx or "$_[0]" =~ /^deconfigure$/msx) {
} elsif ("$_[0]" =~ /^failed-upgrade$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "prerm called with unknown argument \\" . chr(96) . "$_[0]'";
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
if ((("${DPKG_ROOT:-}" eq q{} && "$1" eq remove) && (-d '/run/systemd/system'))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-invoke', 'stop', 'chrony.service') >> 8;
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
}
if ((("${DPKG_ROOT:-}" eq q{} && "$1" eq remove) && (-x "/etc/init.d/chrony"))) {
        $main_exit_code = system('invoke-rc.d', "--skip-" . "sys" . "tem" . "d-native", 'chrony', 'stop') >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/NetworkManager/dispatcher.d/20', '-c', 'hrony', "3.5-7\\~", 'chrony', '--', "@ARGV") >> 8;
exit 0;

exit $main_exit_code;
