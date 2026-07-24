#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use File::Basename;
use IPC::Open3;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

# Original bash: echo "foo123 bar456" | grep -E "(foo|bar)[0-9]+"
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= 'foo123 bar456' . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_0_1;
    my @grep_lines_0_1 = split /\n/msx, $output_0;
    my @grep_filtered_0_1 = grep { /(foo|bar)[0-9]+/msx } @grep_lines_0_1;
    $grep_result_0_1 = join "\n", @grep_filtered_0_1;
    if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
    $grep_result_0_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
    $output_0 = $grep_result_0_1;
    $output_0 = $grep_result_0_1;
    if ((scalar @grep_filtered_0_1) == 0) {
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
# Original bash: echo "a+b*c?" | grep -F "a+b*c?"
{
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 .= 'a+b*c?' . "\n";
if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_1_1;
    my @grep_lines_1_1 = split /\n/msx, $output_1;
    my @grep_filtered_1_1 = grep { /a+b*c?/msx } @grep_lines_1_1;
    $grep_result_1_1 = join "\n", @grep_filtered_1_1;
    if (!($grep_result_1_1 =~ m{\n\z}msx || $grep_result_1_1 eq q{})) {
    $grep_result_1_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
    $output_1 = $grep_result_1_1;
    $output_1 = $grep_result_1_1;
    if ((scalar @grep_filtered_1_1) == 0) {
        $pipeline_success_1 = 0;
    }
    if ($output_1 ne q{} && !defined $output_printed_1) {
        print $output_1;
        if (!($output_1 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    }
# Original bash: echo "word wordly subword" | grep -w "word"
{
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= 'word wordly subword' . "\n";
if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_2_1;
    my @grep_lines_2_1 = split /\n/msx, $output_2;
    my @grep_filtered_2_1 = grep { /word/msx } @grep_lines_2_1;
    $grep_result_2_1 = join "\n", @grep_filtered_2_1;
    if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
    $grep_result_2_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
    $output_2 = $grep_result_2_1;
    $output_2 = $grep_result_2_1;
    if ((scalar @grep_filtered_2_1) == 0) {
        $pipeline_success_2 = 0;
    }
    if ($output_2 ne q{} && !defined $output_printed_2) {
        print $output_2;
        if (!($output_2 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    }
# Original bash: echo -e "exact whole line\npartial line" | grep -x "exact whole line"
{
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= "exact whole line\npartial line";
if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_3_1;
    my @grep_lines_3_1 = split /\n/msx, $output_3;
    my @grep_filtered_3_1 = grep { /exact\ whole\ line/msx } @grep_lines_3_1;
    $grep_result_3_1 = join "\n", @grep_filtered_3_1;
    if (!($grep_result_3_1 =~ m{\n\z}msx || $grep_result_3_1 eq q{})) {
    $grep_result_3_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_3_1 > 0 ? 0 : 1;
    $output_3 = $grep_result_3_1;
    $output_3 = $grep_result_3_1;
    if ((scalar @grep_filtered_3_1) == 0) {
        $pipeline_success_3 = 0;
    }
    if ($output_3 ne q{} && !defined $output_printed_3) {
        print $output_3;
        if (!($output_3 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    }
# Original bash: echo -e "error message\nwarning message\ninfo message" | grep -E "error|warning"
{
    my $output_4 = q{};
    my $output_printed_4;
    my $pipeline_success_4 = 1;
    $output_4 .= "error message\nwarning message\ninfo message";
if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_4_1;
    my @grep_lines_4_1 = split /\n/msx, $output_4;
    my @grep_filtered_4_1 = grep { /error|warning/msx } @grep_lines_4_1;
    $grep_result_4_1 = join "\n", @grep_filtered_4_1;
    if (!($grep_result_4_1 =~ m{\n\z}msx || $grep_result_4_1 eq q{})) {
    $grep_result_4_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_4_1 > 0 ? 0 : 1;
    $output_4 = $grep_result_4_1;
    $output_4 = $grep_result_4_1;
    if ((scalar @grep_filtered_4_1) == 0) {
        $pipeline_success_4 = 0;
    }
    if ($output_4 ne q{} && !defined $output_printed_4) {
        print $output_4;
        if (!($output_4 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
    }
# Original bash: echo -e "error\nwarning" | grep -f <(echo -e "error\nwarning")
{
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;
    $output_5 .= "error\nwarning";
if ( !($output_5 =~ m{\n\z}msx) ) { $output_5 .= "\n"; }
$CHILD_ERROR = 0;

        my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
    my $output_ps_fh_1;
    {
    local *STDOUT;
    open STDOUT, '>', \$output_ps_fh_1 or croak "Cannot redirect STDOUT";
    my $output_6 = q{};
    my $output_printed_6;
    print "error\nwarning" . "\n";
    $CHILD_ERROR = 0;
    if ($output_6 ne q{} && !$output_printed_6) {
    print $output_6;
    }
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_1 = dirname($temp_file_ps_fh_1);
    if (!-d $temp_dir_fh_1) { make_path($temp_dir_fh_1); }
    open my $fh_ps_fh_1, '>', $temp_file_ps_fh_1 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_1} $output_ps_fh_1;
    close $fh_ps_fh_1 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_1 or croak "Cannot open process substitution: $ERRNO\n";
    $output_5 = $output_ps_fh_1;
    my $grep_result_0;
    my @grep_lines_0 = ();
    my @patterns_0 = ();
    if (-e $temp_file_ps_fh_1) {
    open my $fh_0, '<', $temp_file_ps_fh_1 or die "Cannot open pattern file: $ERRNO";
    while (my $line = <$fh_0>) {
    chomp $line;
    push @patterns_0, $line if $line ne q{};
    }
    close($fh_0);
    }
    my @grep_filtered_0 = ();
    for my $line (@grep_lines_0) {
    my $match = 0;
    for my $pattern (@patterns_0) {
    if ($line =~ /$pattern/msx) {
    $match = 1;
    last;
    }
    }
    push @grep_filtered_0, $line if $match;
    }
    $grep_result_0 = join "\n", @grep_filtered_0;
    if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
    $grep_result_0 .= "\n";
    }
    print $grep_result_0;
    $CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1;
    if ($output_5 ne q{} && !defined $output_printed_5) {
        print $output_5;
        if (!($output_5 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    }
{
    my $output_7 = q{};
    my $output_printed_7;
    my $pipeline_success_7 = 1;
    $output_7 .= 'file123.txt backup456.bak' . "\n";
if ( !($output_7 =~ m{\n\z}msx) ) { $output_7 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_7_1;
    my @grep_lines_7_1 = split /\n/msx, $output_7;
    my @grep_filtered_7_1 = grep { /([a-z]+)([0-9]+)[.]([a-z]+)/msx } @grep_lines_7_1;
    $grep_result_7_1 = join "\n", @grep_filtered_7_1;
    if (!($grep_result_7_1 =~ m{\n\z}msx || $grep_result_7_1 eq q{})) {
    $grep_result_7_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_7_1 > 0 ? 0 : 1;
    $output_7 = $grep_result_7_1;
    $output_7 = $grep_result_7_1;
    if ((scalar @grep_filtered_7_1) == 0) {
        $pipeline_success_7 = 0;
    }
    if ($output_7 ne q{} && !defined $output_printed_7) {
        print $output_7;
        if (!($output_7 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
    }

exit $main_exit_code;
