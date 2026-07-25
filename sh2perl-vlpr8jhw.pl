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

$main_exit_code = system('.', './setup-vars') >> 8;
do {
open STDERR, '<', q{0} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};
my $PCT;
my @PCT;
my %PCT;
$PCT = '10';
# Original bash: #!/bin/sh
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        $output_0 = q{};
    my @_pcmd_2 = ('sh', '-c', 'sleep 1');
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', @_pcmd_2);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    my @_pcmd_4 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', @_pcmd_4);
    close $in_3 or croak 'Close failed: $OS_ERROR';
    $output_0 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;

        my $cmd_6 = 'unknown_command';
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', $cmd_6, '--title', '--input-fd', q{3}, '--gauge', q{0}, q{0}, q{0});
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
do {
open STDERR, '<', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};

exit $main_exit_code;
