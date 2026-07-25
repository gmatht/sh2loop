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

print "Testing nested command substitution...\n";
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= "Current dir: " . (defined (defined ($ENV{PWD} // q{}) && ($ENV{PWD} // q{}) ne q{} ? ($ENV{PWD} // q{}) : do { my $_result = do { use Cwd; getcwd(); }; $_result; }) && (defined ($ENV{PWD} // q{}) && ($ENV{PWD} // q{}) ne q{} ? ($ENV{PWD} // q{}) : do { my $_result = do { use Cwd; getcwd(); }; $_result; }) ne q{} ? (defined ($ENV{PWD} // q{}) && ($ENV{PWD} // q{}) ne q{} ? ($ENV{PWD} // q{}) : do { my $_result = do { use Cwd; getcwd(); }; $_result; }) : do { my $_result = do { use Cwd; getcwd(); }; $_result; }) . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

        my $set1_1 = "/\\\\";
    my $input_1 = $output_0;
    my $tr_result_0_1 = q{};
    for my $char ( split //msx, $input_1 ) {
    if ( (index $set1_1, $char) == -1 ) {
    $tr_result_0_1 .= $char;
    }
    }
    if (!($tr_result_0_1 =~ m{\n\z}msx || $tr_result_0_1 eq q{})) {
    $tr_result_0_1 .= "\n";
    }
    $output_0 = $tr_result_0_1;
    $output_0 = $tr_result_0_1;

        my $grep_result_0_2;
    my @grep_lines_0_2 = split /\n/msx, $output_0;
    my @grep_filtered_0_2 = grep { /.....$/msx } @grep_lines_0_2;
    my @grep_matches_0_2;
    foreach my $line (@grep_filtered_0_2) {
    if ($line =~ /(.....$)/msx) {
    push @grep_matches_0_2, $1;
    }
    }
    $grep_result_0_2 = join "\n", @grep_matches_0_2;
    $CHILD_ERROR = scalar @grep_filtered_0_2 > 0 ? 0 : 1;
    $output_0 = $grep_result_0_2;
    $output_0 = $grep_result_0_2;
    if ((scalar @grep_filtered_0_2) == 0) {
        $pipeline_success_0 = 0;
    }
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }

exit $main_exit_code;
