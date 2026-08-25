#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use File::Basename;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use POSIX qw(time);
my $main_exit_code = 0;
our $CHILD_ERROR = 0;
open my $fh, '>', '/tmp/cmp_a.txt' or die "/tmp/cmp_a.txt: $!\n";
print {$fh}("abcdefghij", "\n");
close $fh;
open my $fh, '>', '/tmp/cmp_same.txt' or die "/tmp/cmp_same.txt: $!\n";
print {$fh}("abcdefghij", "\n");
close $fh;
open my $fh, '>', '/tmp/cmp_diff.txt' or die "/tmp/cmp_diff.txt: $!\n";
print {$fh}("abcdeZghij", "\n");
close $fh;
open my $fh, '>', '/tmp/cmp_diff2.txt' or die "/tmp/cmp_diff2.txt: $!\n";
print {$fh}("xyzdefghij", "\n");
close $fh;
open my $fh, '>', '/tmp/cmp_short.txt' or die "/tmp/cmp_short.txt: $!\n";
print {$fh}("abc", "\n");
close $fh;
if ( -e "/tmp/cmp_empty.txt" ) {
    my $current_time = time;
    utime $current_time, $current_time, "/tmp/cmp_empty.txt";
}
else {
    if ( open my $fh, '>', "/tmp/cmp_empty.txt" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "/tmp/cmp_empty.txt",
          ": $ERRNO\n";
    }
}
my $__cmd_1 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_1, '/tmp/cmp_a.txt', '/tmp/cmp_same.txt') >> 8;
print("exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_2 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_2, '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_3 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_3, '/tmp/cmp_a.txt', '/tmp/cmp_empty.txt') >> 8;
print("exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_4 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_4, '/tmp/cmp_empty.txt', '/tmp/cmp_empty.txt') >> 8;
print("exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_5 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_5, '-s', '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-s exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_6 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_6, '-s', '/tmp/cmp_a.txt', '/tmp/cmp_same.txt') >> 8;
print("-s same exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_7 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_7, '-l', '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-l exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_8 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_8, '-b', '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-b exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_9 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_9, '-n', q{5}, '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-n 5 exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_10 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_10, '-n', '10', '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-n 10 exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_11 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_11, '-n', '10', '/tmp/cmp_a.txt', '/tmp/cmp_short.txt') >> 8;
print("-n 10 short exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_12 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_12, '-i', q{6}, '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-i 6 exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_13 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_13, '-i', q{3}, '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-i 3 exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_14 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_14, '-i', '0:6', '/tmp/cmp_a.txt', '/tmp/cmp_diff.txt') >> 8;
print("-i 0:6 exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $__cmd_15 = 'cmp';
$main_exit_code = $CHILD_ERROR = system($__cmd_15, '-i', '5:0', '/tmp/cmp_a.txt', '/tmp/cmp_diff2.txt') >> 8;
print("-i 5:0 exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
my $output_ps_fh_1;
{
    local *STDOUT;
    open STDOUT, '>', \$output_ps_fh_1 or croak "Cannot redirect STDOUT";
    my $output_16 = q{};
    my $output_printed_16;
    print q{a} . "\n";
if ($output_16 ne q{} && !$output_printed_16) {
    print $output_16;
}
}
use File::Path qw(make_path);
my $temp_dir_fh_1 = dirname($temp_file_ps_fh_1);
if (!-d $temp_dir_fh_1) { make_path($temp_dir_fh_1); }
open my $fh_ps_fh_1, '>', $temp_file_ps_fh_1 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_1} $output_ps_fh_1;
close $fh_ps_fh_1 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_1 or croak "Cannot open process substitution: $ERRNO\n";
my $temp_file_ps_fh_2 = q{/tmp} . '/process_sub_fh_2.tmp';
my $output_ps_fh_2;
{
    local *STDOUT;
    open STDOUT, '>', \$output_ps_fh_2 or croak "Cannot redirect STDOUT";
    my $output_17 = q{};
    my $output_printed_17;
    print q{a} . "\n";
if ($output_17 ne q{} && !$output_printed_17) {
    print $output_17;
}
}
use File::Path qw(make_path);
my $temp_dir_fh_2 = dirname($temp_file_ps_fh_2);
if (!-d $temp_dir_fh_2) { make_path($temp_dir_fh_2); }
open my $fh_ps_fh_2, '>', $temp_file_ps_fh_2 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_2} $output_ps_fh_2;
close $fh_ps_fh_2 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_2 or croak "Cannot open process substitution: $ERRNO\n";
$main_exit_code = $CHILD_ERROR = system('cmp', '-s', $temp_file_ps_fh_1, $temp_file_ps_fh_2) >> 8;
print("aa -s exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
my $temp_file_ps_fh_3 = q{/tmp} . '/process_sub_fh_3.tmp';
my $output_ps_fh_3;
{
    local *STDOUT;
    open STDOUT, '>', \$output_ps_fh_3 or croak "Cannot redirect STDOUT";
    my $output_18 = q{};
    my $output_printed_18;
    print q{b} . "\n";
if ($output_18 ne q{} && !$output_printed_18) {
    print $output_18;
}
}
use File::Path qw(make_path);
my $temp_dir_fh_3 = dirname($temp_file_ps_fh_3);
if (!-d $temp_dir_fh_3) { make_path($temp_dir_fh_3); }
open my $fh_ps_fh_3, '>', $temp_file_ps_fh_3 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_3} $output_ps_fh_3;
close $fh_ps_fh_3 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_3 or croak "Cannot open process substitution: $ERRNO\n";
my $temp_file_ps_fh_4 = q{/tmp} . '/process_sub_fh_4.tmp';
my $output_ps_fh_4;
{
    local *STDOUT;
    open STDOUT, '>', \$output_ps_fh_4 or croak "Cannot redirect STDOUT";
    my $output_19 = q{};
    my $output_printed_19;
    print q{c} . "\n";
if ($output_19 ne q{} && !$output_printed_19) {
    print $output_19;
}
}
use File::Path qw(make_path);
my $temp_dir_fh_4 = dirname($temp_file_ps_fh_4);
if (!-d $temp_dir_fh_4) { make_path($temp_dir_fh_4); }
open my $fh_ps_fh_4, '>', $temp_file_ps_fh_4 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_4} $output_ps_fh_4;
close $fh_ps_fh_4 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_4 or croak "Cannot open process substitution: $ERRNO\n";
$main_exit_code = $CHILD_ERROR = system('cmp', '-s', $temp_file_ps_fh_3, $temp_file_ps_fh_4) >> 8;
print("bc -s exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;
unlink('/tmp/cmp_a.txt');
unlink('/tmp/cmp_same.txt');
unlink('/tmp/cmp_diff.txt');
unlink('/tmp/cmp_diff2.txt');
unlink('/tmp/cmp_short.txt');
unlink('/tmp/cmp_empty.txt');
