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

my $msg;
my @msg;
my %msg;
my $prev_msg;
my @prev_msg;
my %prev_msg;

$msg = q{};
$prev_msg = q{};
while ( 1 ) {
require Time::HiRes; Time::HiRes::sleep('0.5');
        $msg = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;

        my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'snap', 'change', '--abs-time', '--last=seed?');
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
        my @lines = split /\n/msx, $output_2;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ +/msx, $line;
            if (!($fields[0] == "Doing")) { next; }
            push @result, (substr($line . index($line . $fields[3])); exit . "\n");
        }
        $output_2 = join "", @result;

        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        $output_2 =~ s/\n+\z//msx;
        $output_2;
}; $_pipeline_result; };
    if ($CHILD_ERROR != 0) {
        1;
    }
if (("$msg" ne "$prev_msg" && "$msg" ne q{})) {
        $main_exit_code = system('plymouth', 'display-message', '--text', "$msg") >> 8;
        $prev_msg = $msg;
    }
}

exit $main_exit_code;
