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

my $attempts;
my @attempts;
my %attempts;
my $attempt;
my @attempt;
my %attempt;
my $dadfailed;
my @dadfailed;
my %dadfailed;
my $tentative;
my @tentative;
my %tentative;

$attempts = (defined ($ENV{IF_DAD_ATTEMPTS} // q{}) && ($ENV{IF_DAD_ATTEMPTS} // q{}) ne q{} ? ($ENV{IF_DAD_ATTEMPTS} // q{}) : '60');
my $delay;
my @delay;
my %delay;
$delay = (defined ($ENV{IF_DAD_INTERVAL} // q{}) && ($ENV{IF_DAD_INTERVAL} // q{}) ne q{} ? ($ENV{IF_DAD_INTERVAL} // q{}) : '0.1');
if (($attempts == 0)) {
    exit 0;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
print "Waiting for DAD... ";
for my $attempt (do { my $first; my $last; $first = q{1}; $last = $attempts; join "\n", $first..$last; }) {
    $tentative = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;

        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'ip', '-o', '-6', 'address', 'list', 'dev', 'to', 'tentative');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        $output_0 = do {
                    my $_wc_data = $output_0;
                    my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                    my $_wc_result = q{};
                    $_wc_result .= sprintf q{%d}, $_wc_lines;
                    $_wc_result .= "\n";
                    $_wc_result;
                };
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; };
if (($tentative == 0)) {
        $attempt = q{0};
last;
    }
require Time::HiRes; Time::HiRes::sleep($delay);
}
$attempt = $last; };
if (($attempt == $attempts)) {
    print "Timed out\n";
exit 1;
}
$dadfailed = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;

    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'ip', '-o', '-6', 'address', 'list', 'dev', 'to', 'dadfailed');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
    $output_3 = do {
            my $_wc_data = $output_3;
            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_lines;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    $output_3 =~ s/\n+\z//msx;
    $output_3;
}; $_pipeline_result; };
if (($dadfailed >= 1)) {
    print "Failed\n";
exit 1;
}
print 'Done' . "\n";
$CHILD_ERROR = 0;

exit $main_exit_code;
