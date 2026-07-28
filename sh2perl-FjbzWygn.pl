#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $output         = q{};
our $CHILD_ERROR;

my $size_diff;
my $BASE_PKG_VERSION;
my $mode;

my $TC;
my $RED;
my $GREEN;
if (((-t1) || (-p /dev/stdout))) {
    $RED = "\\033[0;31m";
    $GREEN = "\\033[0;32m";
    $TC = "\\033[0m";
}

sub calc_perc {
my $temp_content = '    scale=2;
    define abs2(x) { if (x < 0) return -x; return x }
    ratio=$1/$2;
    if (ratio >= 0.01) {
      if (ratio < 0) {
        print "-"
      } else {
        print "+"
      }
      if (abs2(ratio) < 1) {
        print "0"
      }
      print abs2(ratio)
      print "% "
    }
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
    $main_exit_code = system('bash', 'bc') >> 8;
    return;
}
if ("$BASE_PKG_VERSION" eq q{}) {
    $BASE_PKG_VERSION = (do {
    do { do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;

        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'npm', 'version', '--json');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }

        my $cmd_3 = 'python3';
        my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', $cmd_3, '-c', "import json; import sys; print(json.loads(sys.stdin.read()).get(\"jschardet\"))");
        print {$in_2} $output_0;
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; };
});
}
my $BASE_PKG_VERSION_HASH = (do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'git', 'rev-list', '-n', q{1}, q{v}, $BASE_PKG_VERSION);
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
});
say "Bundle size changes since v$BASE_PKG_VERSION:";
# Original bash: eval "git diff-index "$BASE_PKG_VERSION_HASH" $@" | {
do {
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;
        my @_pcmd_7 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
    my ($in_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', @_pcmd_7);
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $temp_result;
    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    $output_5 = $temp_result;
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;

        my @_pcmd_9 = ('bash', '-c', "echo \"${output_5}\" | : \"Complex command cannot be converted to shell command\"");
    my ($in_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', @_pcmd_9);
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $temp_result;
    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    $output_5 = $temp_result;
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    if ($output_5 ne q{} && !defined $output_printed_5) {
        print $output_5;
        if (!($output_5 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    }
}
