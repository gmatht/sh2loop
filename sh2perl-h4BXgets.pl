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
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'py3clean') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $main_exit_code = system('py3clean', '-p', 'python3-attr') >> 8;
}
else {
    # Original bash: dpkg -L python3-attr | sed -En -e '/^(.*)\/(.+)\.py$/s,,rm "\1/__pycache__/\2".*,e'
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'dpkg', '-L', 'python3-attr');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    # Original bash: find /usr/lib/python3/dist-packages/ -type d -name __pycache__ -empty -print0 | xargs --null --no-run-if-empty rmdir
{
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
                $output_2 = do {
        require File::Find;
        my @find_results;
        File::Find::find(sub { if (-d $_ && $_ =~ /^__pycache__$/msx) { push @find_results, $File::Find::name; } }, '/usr/lib/python3/dist-packages/');
        my $result = join "\n", @find_results;
        if ($result ne q{}) { $result .= "\n"; }
        $CHILD_ERROR = 0;
        $result;
        };

                my @xargs_input_2_1 = grep { $_ ne q{} } split /\s+/msx, $output_2;
        my @xargs_output_2_1;
        for my $i (0..scalar @xargs_input_2_1-1) {
        my @xargs_args_2_1;
        for my $j (0..1-1) {
        push @xargs_args_2_1, $xargs_input_2_1[$i + $j];
        }
        my ($in_2_1, $out_2_1, $err_2_1);
        my $cmd_xargs_2_1 = 'rmdir';
        my $pid_2_1 = open3($in_2_1, $out_2_1, $err_2_1, $cmd_xargs_2_1, @xargs_args_2_1);
        close $in_2_1 or croak 'Close failed: $OS_ERROR';
        my $xargs_result_2_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2_1> };
        close $out_2_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2_1, 0;
        chomp $xargs_result_2_1;
        push @xargs_output_2_1, $xargs_result_2_1;
        }
        my $xargs_result_2_1 = join "\n", @xargs_output_2_1;
        if ($xargs_result_2_1 ne q{} && !( $xargs_result_2_1 =~ m{\n\z}msx )) { $xargs_result_2_1 .= "\n"; }
        $output_2 = $xargs_result_2_1;
        $output_2 = $xargs_result_2_1;
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
}

exit $main_exit_code;
