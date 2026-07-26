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

my $NR_NOTIFYD_DISABLE_WRITE;
my @NR_NOTIFYD_DISABLE_WRITE;
my %NR_NOTIFYD_DISABLE_WRITE;

$main_exit_code = system('.', '/usr/lib/needrestart/notify.d.sh') >> 8;
if ("$NR_NOTIFYD_DISABLE_WRITE" eq '1') {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "[$PROGRAM_NAME] disabled in global config";
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
if ("$ENV{NR_SESSION}" =~ /^/dev/tty.*$/msx or "$ENV{NR_SESSION}" =~ /^/dev/pts.*$/msx) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "[$PROGRAM_NAME] notify user $ENV{NR_USERNAME} on $ENV{NR_SESSION}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
        # Original bash: #!/bin/sh
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my @_pcmd_2 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
        my ($in_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', @_pcmd_2);
        close $in_1 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        $output_0 = $temp_result;
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my $cmd_4 = 'write';
        my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', $cmd_4, );
        print {$in_3} $output_0;
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "[$PROGRAM_NAME] skip session w/o tty";
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
