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

print "start\n";
do {
my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
my $output_ps_fh_1;
{
    local *STDOUT;
    open STDOUT, '>', \$output_ps_fh_1 or croak "Cannot redirect STDOUT";
    my $output_0 = q{};
    my $output_printed_0;
    print q{a} . "\n";
    $CHILD_ERROR = 0;
if ($output_0 ne q{} && !$output_printed_0) {
    print $output_0;
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
    my $output_1 = q{};
    my $output_printed_1;
    print q{b} . "\n";
    $CHILD_ERROR = 0;
if ($output_1 ne q{} && !$output_printed_1) {
    print $output_1;
}
}
use File::Path qw(make_path);
my $temp_dir_fh_2 = dirname($temp_file_ps_fh_2);
if (!-d $temp_dir_fh_2) { make_path($temp_dir_fh_2); }
open my $fh_ps_fh_2, '>', $temp_file_ps_fh_2 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_2} $output_ps_fh_2;
close $fh_ps_fh_2 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_2 or croak "Cannot open process substitution: $ERRNO\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    $ENV{DIFF_TEMP_FILE1} = q{/tmp} . '/process_sub_fh_1.tmp';
    $ENV{DIFF_TEMP_FILE2} = q{/tmp} . '/process_sub_fh_2.tmp';
    my $diff_output = q{};
    {
        my $diff_cmd = 'diff';
        my @diff_args = ($temp_file_ps_fh_1, $temp_file_ps_fh_2);
        my $diff_pid = open my $diff_fh, q{-|}, $diff_cmd, @diff_args;
        if ($diff_pid) {
            local $INPUT_RECORD_SEPARATOR = undef;
            $diff_output = <$diff_fh>;
            close $diff_fh;
            $CHILD_ERROR = $? >> 8;
        } else {
            carp "Cannot execute diff command: $OS_ERROR";
            $diff_output = q{};
            $CHILD_ERROR = 1;
        }
    }
    print $diff_output;
};
if ($CHILD_ERROR != 0) {
    1;
}
print "end\n";

exit $main_exit_code;
