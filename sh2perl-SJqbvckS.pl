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

{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my @results;
    if (-f 'df') {
    my ($in_1);
    my $pid_1 = open3($in_1, $out_1, $err_1, 'bash', '-c', q{gzip 'df'});
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    if ( $CHILD_ERROR == 0 ) {
    push @results, "Compressed: 'df'";
    } else {
    push @results, "Failed to compress: 'df'";
    }
    } else {
    push @results, "File not found: 'df'";
    }
    if (-f "@ARGV") {
    my ($in_2);
    my $pid_2 = open3($in_2, $out_2, $err_2, 'bash', '-c', 'gzip "@ARGV"');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    if ( $CHILD_ERROR == 0 ) {
    push @results, "Compressed: "@ARGV"";
    } else {
    push @results, "Failed to compress: "@ARGV"";
    }
    } else {
    push @results, "File not found: "@ARGV"";
    }
    = join "\n", @results;

        my $grep_result_0_1;
    my @grep_lines_0_1 = split /\n/msx, $output_0;
    my @grep_filtered_0_1 = grep { !/^(\#|$)/msx } @grep_lines_0_1;
    $grep_result_0_1 = join "\n", @grep_filtered_0_1;
    if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
    $grep_result_0_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
    $output_0 = $grep_result_0_1;
    $output_0 = $grep_result_0_1;

        my $set1_3 = '[A-Z]';
    my $set2_3 = '[a-z]';
    my $input_3 = $output_0;
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
    my $tr_result_0_2 = q{};
    for my $char ( split //msx, $input_3 ) {
    my $pos_3 = index $expanded_set1_3, $char;
    if ( $pos_3 >= 0 && $pos_3 < length $expanded_set2_3 ) {
    $tr_result_0_2 .= substr $expanded_set2_3, $pos_3, 1;
    } else {
    $tr_result_0_2 .= $char;
    }
    }
    if (!($tr_result_0_2 =~ m{\n\z}msx || $tr_result_0_2 eq q{})) {
    $tr_result_0_2 .= "\n";
    }
    $output_0 = $tr_result_0_2;
    $output_0 = $tr_result_0_2;

        my $set1_4 = '-c';
    my $set2_4 = q{d};
    my $input_4 = $output_0;
    # Expand character ranges for tr command
    my $expanded_set1_4 = $set1_4;
    my $expanded_set2_4 = $set2_4;
    # Handle a-z range in set1
    if ($expanded_set1_4 =~ /a-z/msx) {
    $expanded_set1_4 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set1
    if ($expanded_set1_4 =~ /A-Z/msx) {
    $expanded_set1_4 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set1
    if ($expanded_set1_4 =~ /\[:upper:\]/msx) {
    $expanded_set1_4 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set1
    if ($expanded_set1_4 =~ /\[:lower:\]/msx) {
    $expanded_set1_4 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle a-z range in set2
    if ($expanded_set2_4 =~ /a-z/msx) {
    $expanded_set2_4 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set2
    if ($expanded_set2_4 =~ /A-Z/msx) {
    $expanded_set2_4 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set2
    if ($expanded_set2_4 =~ /\[:upper:\]/msx) {
    $expanded_set2_4 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set2
    if ($expanded_set2_4 =~ /\[:lower:\]/msx) {
    $expanded_set2_4 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    my $tr_result_0_3 = q{};
    for my $char ( split //msx, $input_4 ) {
    my $pos_4 = index $expanded_set1_4, $char;
    if ( $pos_4 >= 0 && $pos_4 < length $expanded_set2_4 ) {
    $tr_result_0_3 .= substr $expanded_set2_4, $pos_4, 1;
    } else {
    $tr_result_0_3 .= $char;
    }
    }
    if (!($tr_result_0_3 =~ m{\n\z}msx || $tr_result_0_3 eq q{})) {
    $tr_result_0_3 .= "\n";
    }
    $output_0 = $tr_result_0_3;
    $output_0 = $tr_result_0_3;

        my $cmd_6 = 'env';
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', $cmd_6, 'LC_ALL', q{=}, q{C}, 'sort', '-u');
    print {$in_5} $output_0;
    close $in_5 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }

exit $main_exit_code;
