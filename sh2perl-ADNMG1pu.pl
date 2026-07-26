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

my $INIT_EXEC;
my @INIT_EXEC;
my %INIT_EXEC;
my $NR_VERBOSE;
my @NR_VERBOSE;
my %NR_VERBOSE;
my $DISPLAY_MANAGER;
my @DISPLAY_MANAGER;
my %DISPLAY_MANAGER;

if ("$NR_VERBOSE" eq '1') {
# set -x not implemented
}
if ("$(id -ru)" ne "0") {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "Not root, exiting\n";
    };
exit 1;
}
$INIT_EXEC = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'readlink', '/proc/1/exe');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
if ("$(basename "$INIT_EXEC")" ne "systemd") {
    do {
    my $__echo_line = "Init " . "sys" . "tem" . " is not " . "sys" . "tem" . "d ($INIT_EXEC), doing nothing";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 0;
}

sub get_active_deps {
    # Original bash: #!/bin/bash
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
                my @_pcmd_3 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
        my ($in_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', @_pcmd_3);
        close $in_2 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        $output_1 = $temp_result;
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;

                my $grep_result_1_1;
        my @grep_lines_1_1 = split /\n/msx, $output_1;
        my @grep_filtered_1_1 = grep { /[^[:space:]]+.service/msx } @grep_lines_1_1;
        my @grep_matches_1_1;
        foreach my $line (@grep_filtered_1_1) {
        if ($line =~ /([^[:space:]]+.service)/msx) {
        push @grep_matches_1_1, $1;
        }
        }
        $grep_result_1_1 = join "\n", @grep_matches_1_1;
        $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
        $output_1 = $grep_result_1_1;
        $output_1 = $grep_result_1_1;

                my @sort_lines_1_2 = split /\n/msx, $output_1;
        my @sort_sorted_1_2 = sort @sort_lines_1_2;
        my $output_1_2 = join "\n", @sort_sorted_1_2;
        if ($output_1_2 ne q{} && !($output_1_2 =~ m{\n\z}msx)) {
        $output_1_2 .= "\n";
        }
        $output_1 = $output_1_2;
        $output_1 = $output_1_2;

                my @lines = split /\n/msx, $output_1;
        my $result_1_3 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        if ((("$SERVICE" ne "dbus.service" && "$SERVICE" ne "$DISPLAY_MANAGER") && !(        $main_exit_code = system('systemctl', '-q', 'is-active', "$ENV{SERVICE}") >> 8))) {
        print $SERVICE;
        if ( !( ($SERVICE) =~ m{\n\z}msx ) ) { print "\n"; }
        }
        }
        $output_1 = $result_1_3;
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        }
    return;
}
$DISPLAY_MANAGER = (do { my $_chomp_temp = do {
    my $left_result_4 = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', "sys" . "tem" . "ctl", '-q', 'is-active', 'display-manager.service');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_4 = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', "sys" . "tem" . "ctl", 'show', '--value', '-p', 'Id', 'display-manager.service');
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
        $left_result_4 . $right_result_4;
    } else {
        q{};
    }
}; chomp $_chomp_temp; $_chomp_temp; });
my $ACTIVE_DEPS;
my @ACTIVE_DEPS;
my %ACTIVE_DEPS;
$ACTIVE_DEPS = (do { my $_chomp_temp = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'get_active_deps');
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}; chomp $_chomp_temp; $_chomp_temp; });
my $SESSIONS;
my @SESSIONS;
my %SESSIONS;
$SESSIONS = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_8 = q{};
    my $output_printed_8;
    my $pipeline_success_8 = 1;

    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'loginctl', 'list-sessions', '--no-legend');
    close $in_9 or croak 'Close failed: $OS_ERROR';
    $output_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_8 = 0; }
    my $grep_result_8_1;
    my @grep_lines_8_1 = split /\n/msx, $output_8;
    my @grep_filtered_8_1 = grep { /^[[:space:]]*[0-9]+/msx } @grep_lines_8_1;
    my @grep_matches_8_1;
    foreach my $line (@grep_filtered_8_1) {
        if ($line =~ /(^[[:space:]]*[0-9]+)/msx) {
            push @grep_matches_8_1, $1;
        }
    }
    $grep_result_8_1 = join "\n", @grep_matches_8_1;
    $CHILD_ERROR = scalar @grep_filtered_8_1 > 0 ? 0 : 1;
    $output_8 = $grep_result_8_1;
    my $set1_10 = "\\n";
    my $set2_10 = q{ };
    my $input_10 = $output_8;
    # Expand character ranges for tr command
    my $expanded_set1_10 = $set1_10;
    my $expanded_set2_10 = $set2_10;
    # Handle a-z range in set1
    if ($expanded_set1_10 =~ /a-z/msx) {
        $expanded_set1_10 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set1
    if ($expanded_set1_10 =~ /A-Z/msx) {
        $expanded_set1_10 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set1
    if ($expanded_set1_10 =~ /\[:upper:\]/msx) {
        $expanded_set1_10 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set1
    if ($expanded_set1_10 =~ /\[:lower:\]/msx) {
        $expanded_set1_10 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle a-z range in set2
    if ($expanded_set2_10 =~ /a-z/msx) {
        $expanded_set2_10 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set2
    if ($expanded_set2_10 =~ /A-Z/msx) {
        $expanded_set2_10 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set2
    if ($expanded_set2_10 =~ /\[:upper:\]/msx) {
        $expanded_set2_10 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set2
    if ($expanded_set2_10 =~ /\[:lower:\]/msx) {
        $expanded_set2_10 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    my $tr_result_8_2 = q{};
    for my $char ( split //msx, $input_10 ) {
        my $pos_10 = index $expanded_set1_10, $char;
        if ( $pos_10 >= 0 && $pos_10 < length $expanded_set2_10 ) {
            $tr_result_8_2 .= substr $expanded_set2_10, $pos_10, 1;
        } else {
            $tr_result_8_2 .= $char;
        }
    }
        if (!($tr_result_8_2 =~ m{\n\z}msx || $tr_result_8_2 eq q{})) {
            $tr_result_8_2 .= "\n";
        }
        $output_8 = $tr_result_8_2;
    if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
    $output_8 =~ s/\n+\z//msx;
    $output_8;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
print "!!! In $PAUSE seconds dbus restart will be performed !!!
User sessions to be terminated: $SESSIONS

Services to be restarted:
$ACTIVE_DEPS
$DISPLAY_MANAGER
";
if ((-t0)) {
    $PRESSENTER = <>;
chomp $PRESSENTER;
$CHILD_ERROR = defined($PRESSENTER) ? 0 : 1;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$ACTIVE_DEPS = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$ACTIVE_DEPS") . "\n";
    my $set1_13 = "\\n";
my $set2_13 = q{ };
my $input_13 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_13 = $set1_13;
my $expanded_set2_13 = $set2_13;
# Handle a-z range in set1
if ($expanded_set1_13 =~ /a-z/msx) {
    $expanded_set1_13 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_13 =~ /A-Z/msx) {
    $expanded_set1_13 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_13 =~ /\[:upper:\]/msx) {
    $expanded_set1_13 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_13 =~ /\[:lower:\]/msx) {
    $expanded_set1_13 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_13 =~ /a-z/msx) {
    $expanded_set2_13 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_13 =~ /A-Z/msx) {
    $expanded_set2_13 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_13 =~ /\[:upper:\]/msx) {
    $expanded_set2_13 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_13 =~ /\[:lower:\]/msx) {
    $expanded_set2_13 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_12 = q{};
for my $char ( split //msx, $input_13 ) {
    my $pos_13 = index $expanded_set1_13, $char;
    if ( $pos_13 >= 0 && $pos_13 < length $expanded_set2_13 ) {
        $tr_result_12 .= substr $expanded_set2_13, $pos_13, 1;
    } else {
        $tr_result_12 .= $char;
    }
}
$tr_result_12
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("$DISPLAY_MANAGER" ne q{}) {
    $main_exit_code = system('systemd-run', '-G', '--unit=restart-dbus', 'sh', '-c', "loginctl terminate-session $SESSIONS ; " . "sys" . "tem" . "ctl stop $DISPLAY_MANAGER ; " . "sys" . "tem" . "ctl restart dbus.service ; sleep 1 ; " . "sys" . "tem" . "ctl daemon-reexec ; sleep 1 ; " . "sys" . "tem" . "ctl restart $ACTIVE_DEPS ; " . "sys" . "tem" . "ctl start $DISPLAY_MANAGER") >> 8;
}
else {
    $main_exit_code = system('systemd-run', '-G', '--unit=restart-dbus', 'sh', '-c', "loginctl terminate-session $SESSIONS ; " . "sys" . "tem" . "ctl restart dbus.service ; sleep 1 ; " . "sys" . "tem" . "ctl daemon-reexec ; sleep 1 ; " . "sys" . "tem" . "ctl restart $ACTIVE_DEPS") >> 8;
}

exit $main_exit_code;
