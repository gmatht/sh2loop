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
$ENV{LANG} = 'C';
if (((!"$1") || (!"$2"))) {
    do {
    my $__echo_line = "Usage: $PROGRAM_NAME IFACE targetMAC";
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
# Original bash: ip -brief link show dev "$1" | read iface state mac rest
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'ip', '-b', 'rief', 'link', 'show', 'dev');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        $iface = $output_0;
    $CHILD_ERROR = 0;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    }
my $targetmac;
my @targetmac;
my %targetmac;
$targetmac = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[1]") . "\n";
    my $set1_3 = 'A-F';
my $set2_3 = 'a-f';
my $input_3 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_3 = $set1_3;
my $expanded_set2_3 = $set2_3;
# Handle a-z range in set1
if ($expanded_set1_3 =~ /a-z/msx) {
    $expanded_set1_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_3 =~ /A-Z/msx) {
    $expanded_set1_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_3 =~ /\[:upper:\]/msx) {
    $expanded_set1_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_3 =~ /\[:lower:\]/msx) {
    $expanded_set1_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_3 =~ /a-z/msx) {
    $expanded_set2_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_3 =~ /A-Z/msx) {
    $expanded_set2_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_3 =~ /\[:upper:\]/msx) {
    $expanded_set2_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_3 =~ /\[:lower:\]/msx) {
    $expanded_set2_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_2 = q{};
for my $char ( split //msx, $input_3 ) {
    my $pos_3 = index $expanded_set1_3, $char;
    if ( $pos_3 >= 0 && $pos_3 < length $expanded_set2_3 ) {
        $tr_result_2 .= substr $expanded_set2_3, $pos_3, 1;
    } else {
        $tr_result_2 .= $char;
    }
}
$tr_result_2
}; $_pipeline_result; };
$main_exit_code = system('test', "$targetmac", q{=}, "$ENV{mac}") >> 8;

exit $main_exit_code;
