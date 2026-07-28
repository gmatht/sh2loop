#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $output         = q{};
our $CHILD_ERROR;

chdir('/var/lib/ofm');
$CHILD_ERROR = 0;
# Original bash: zgrep -H "$@" `find -L . -name du.gz | sed s,^[.]/,,` | perl -pe 's/\t([\d]{10})\t/"\t".(localtime $1)."\t"/eg;'
do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'zgrep', '-H');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        my $perl_output_2 = do {
    my $result = qx{perl '-p' q{e} "\"s/\\\\t([\\\\d]{10})\\\\t/\\\"\\\\t\\\".(localtime \\\$1).\\\"\\\\t\\\"/eg;\""};
    chomp $result;
    $result;
    };
    print $perl_output_2;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }
