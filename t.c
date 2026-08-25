#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use IPC::Open3;
my $main_exit_code = 0;
our $CHILD_ERROR = 0;
for my $i (do { my $__cs = do { my $first; my $last; $first = q{1}; $last = '10000'; join "\n", $first..$last; }; chomp $__cs; $__cs; }) {
if (!do { local $CHILD_ERROR;     # Original bash: echo $((i*i)) | grep 1337 > /dev/null 2> /dev/null
do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= int($i*$i) . "\n";
if ( !($output_0 =~ m{\n\z}) ) { $output_0 .= "\n"; }

                my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /1337/ } @grep_lines_0_1;
        $grep_result_0_1 = join "\n", @grep_filtered_0_1;
        if (!($grep_result_0_1 =~ m{\n\z} || $grep_result_0_1 eq q{})) {
        $grep_result_0_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
        $output_0 = $grep_result_0_1;
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }; }) {
        print($i, "\n");
        $CHILD_ERROR = 0;
    }
}
