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
        my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'git', 'rev-list', '--objects', '--all');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        my @sort_lines_0_1 = split /\n/msx, $output_0;
    my @sort_sorted_0_1 = sort @sort_lines_0_1;
    my $output_0_1 = join "\n", @sort_sorted_0_1;
    if ($output_0_1 ne q{} && !($output_0_1 =~ m{\n\z}msx)) {
    $output_0_1 .= "\n";
    }
    $output_0 = $output_0_1;
    $output_0 = $output_0_1;

        my $perl_output_2 = do {
    my $result = qx{perl '-lne' "\"\n  substr(\\$_, 40) = \\\"\\\";\n  # uncomment next line for a distribution of bits instead of hex chars\n  # \\$_ = unpack(\\\"B*\\\",pack(\\\"H*\\\",\\$_));\n  if (defined \\$p) {\n    (\\$p ^ \\$_) =~ /^(\\\\0*)/;\n    \\$common = length \\$1;\n    if (defined \\$pcommon) {\n      \\$count[\\$pcommon > \\$common ? \\$pcommon : \\$common]++;\n    } else {\n      \\$count[\\$common]++; # first item\n    }\n  }\n  \\$p = \\$_;\n  \\$pcommon = \\$common;\n  END {\n    \\$count[\\$common]++; # last item\n    print \\\"\\$_: \\$count[\\$_]\\\" for 0..\\$#count;\n  }\n\""};
    chomp $result;
    $result;
    };
    print $perl_output_2;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }

exit $main_exit_code;
