#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $OPT = q{};
if (((scalar(@ARGV) > 0) && $1 eq "-u")) {
    $OPT = '-u';
# Builtin command 'shift' not implemented
}
my $URL;
if ($# eq 0) {
    $URL = $WWW_HOME;
}
else {
    $URL = $1;
}
# Original bash: w3m -dump_source $URL | makeref $OPT -url $URL | w3m -dump -F -T text/html
do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'w3m', '-d', 'ump_source');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        my $cmd_3 = 'makeref';
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', $cmd_3, '-u', 'rl');
    print {$in_2} $output_0;
    close $in_2 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;

        my $cmd_5 = 'w3m';
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', $cmd_5, '-d', 'ump', '-F', '-T', 'text/html');
    print {$in_4} $output_0;
    close $in_4 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }

exit $main_exit_code;
