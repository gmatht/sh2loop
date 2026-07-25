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
        $output_0 = q{};
    my @_pcmd_2 = ('sh', '-c', q{((echo 'Level 3'; (echo 'Level 4'; echo 'Still level 4')) | grep Level) | sed s/Level/Depth/});
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', @_pcmd_2);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        my $output_0_1 = do {
    my $_wc_data = $output_0;
    my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
    my $_wc_result = q{};
    $_wc_result .= sprintf q{%d}, $_wc_lines;
    $_wc_result .= "\n";
    $_wc_result;
    };
    $output_0 = $output_0_1;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }

exit $main_exit_code;
