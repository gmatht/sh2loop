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

my $IF_WPA_ROAM_MAINT_DEBUG;
my @IF_WPA_ROAM_MAINT_DEBUG;
my %IF_WPA_ROAM_MAINT_DEBUG;

if ("$IF_WPA_ROAM_MAINT_DEBUG" ne q{}) {
# set -x not implemented
}
if (("$1" eq q{} || "$2" eq q{})) {
    do {
    my $__echo_line = "Usage: $PROGRAM_NAME IFACE ACTION";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 1;
}
my $WPA_IFACE;
my @WPA_IFACE;
my %WPA_IFACE;
$WPA_IFACE = "$_[0]";
my $WPA_ACTION;
my @WPA_ACTION;
my %WPA_ACTION;
$WPA_ACTION = "$_[1]";
if ((-f '/etc/wpa_supplicant/functions.sh')) {
    $main_exit_code = system('.', '/etc/wpa_supplicant/functions.sh') >> 8;
}
else {
exit 0;
}
if ("$WPA_ACTION" =~ /^CONNECTED$/msx) {
        $main_exit_code = system('bash', 'wpa_log_env') >> 8;
            $main_exit_code = system('bash', 'wpa_hysteresis_check') >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
        $main_exit_code = system('bash', 'wpa_hysteresis_event') >> 8;
    if (!(    $main_exit_code = system('bash', 'ifup') >> 8)) {
        # Original bash: wpa_cli status | wpa_msg log
{
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;
                        my ($in_1, $out_1);
            my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'wpa_cli', 'status');
            close $in_1 or croak 'Close failed: $OS_ERROR';
            $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
            close $out_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_1, 0;

                        my $cmd_3 = 'wpa_msg';
            my ($in_2, $out_2);
            my $pid_2 = open3($in_2, $out_2, '>&STDERR', $cmd_3, 'log');
            print {$in_2} $output_0;
            close $in_2 or croak 'Close failed: $OS_ERROR';
            $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
            close $out_2 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_2, 0;
            if ($output_0 ne q{} && !defined $output_printed_0) {
                print $output_0;
                if (!($output_0 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
            }
}
    else {
        # Original bash: wpa_cli status | wpa_msg log
{
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
                        my ($in_5, $out_5);
            my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'wpa_cli', 'status');
            close $in_5 or croak 'Close failed: $OS_ERROR';
            $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
            close $out_5 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_5, 0;

                        my $cmd_7 = 'wpa_msg';
            my ($in_6, $out_6);
            my $pid_6 = open3($in_6, $out_6, '>&STDERR', $cmd_7, 'log');
            print {$in_6} $output_4;
            close $in_6 or croak 'Close failed: $OS_ERROR';
            $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
            close $out_6 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_6, 0;
            if ($output_4 ne q{} && !defined $output_printed_4) {
                print $output_4;
                if (!($output_4 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
            }
        $main_exit_code = system('wpa_cli', 'reassociate') >> 8;
    }
} elsif ("$WPA_ACTION" =~ /^DISCONNECTED$/msx) {
        $main_exit_code = system('bash', 'wpa_log_env') >> 8;
            $main_exit_code = system('bash', 'wpa_hysteresis_check') >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
        $main_exit_code = system('bash', 'ifdown') >> 8;
        $main_exit_code = system('bash', 'if_post_down_up') >> 8;
} elsif ("$WPA_ACTION" =~ /^stop$/msx or "$WPA_ACTION" =~ /^down$/msx) {
        if (do {
$main_exit_code = system('bash', 'test_wpa_cli') >> 8;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('bash', 'kill_wpa_cli') >> 8;
    }
        $main_exit_code = system('bash', 'ifdown') >> 8;
        if (do {
$main_exit_code = system('bash', 'test_wpa_supplicant') >> 8;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('bash', 'kill_wpa_supplicant') >> 8;
    }
} elsif ("$WPA_ACTION" =~ /^restart$/msx or "$WPA_ACTION" =~ /^reload$/msx) {
            $main_exit_code = system('bash', 'test_wpa_supplicant') >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
        $main_exit_code = system('bash', 'reload_wpa_supplicant') >> 8;
} elsif ("$WPA_ACTION" =~ /^check$/msx) {
            $main_exit_code = system('bash', 'test_wpa_supplicant') >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
            $main_exit_code = system('bash', 'test_wpa_cli') >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
} elsif (1) {
        do {
    my $__echo_line = "Unknown action: \"$WPA_ACTION\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    exit 1;
}
exit 0;

exit $main_exit_code;
