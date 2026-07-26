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
chdir((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$PROGRAM_NAME"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }));
$CHILD_ERROR = 0;
print "Running full test suite to get current failure count...\n";
chdir('sh2perl');
$CHILD_ERROR = 0;
# Original bash: ../fail 2>&1 | tee /tmp/fail_output.txt
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_1 = q{};

my $cmd_4 = '../fail';
my ($in_3, $out_3);
my $pid_3 = open3($in_3, $out_3, '>&STDERR', $cmd_4, );
print {$in_3} $output_0;
close $in_3 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
close $out_3 or croak 'Close failed: $OS_ERROR';
waitpid $pid_3, 0;
$tmp_redirect_1;
    };
    $output_0 = $output;

        use Carp qw(carp croak);
    if ( open my $fh, '>', '/tmp/fail_output.txt' ) {
    print {$fh} $output_0;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open '/tmp/fail_output.txt': $ERRNO";
    }
    $output_0 = $output_0;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    }
my $FAIL_COUNT;
my @FAIL_COUNT;
my %FAIL_COUNT;
$FAIL_COUNT = do {
    my $command = q{grep -c '^  FAIL:' /tmp/fail_output.txt || true};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
do {
    my $__echo_line = "FAIL lines: $FAIL_COUNT";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
# Original bash: grep '^  FAIL:' /tmp/fail_output.txt | sed 's/^  FAIL: //;s/ \[perl\].*//' > failing_tests.txt
{
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;
        my $grep_result_5_0;
    my @grep_lines_5_0 = ();
    my @grep_filenames_5_0 = ();
    if (-e "/tmp/fail_output.txt") {
    open my $fh, '<', "/tmp/fail_output.txt" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
    chomp $line;
    push @grep_lines_5_0, $line;
    push @grep_filenames_5_0, "/tmp/fail_output.txt";
    }
    close $fh
    or croak "Close failed: $OS_ERROR";
    }
    else { print {*STDERR} "grep: /tmp/fail_output.txt: No such file or directory\n"; }
    my @grep_filtered_5_0 = grep { /^\ \ FAIL:/msx } @grep_lines_5_0;
    $grep_result_5_0 = join "\n", @grep_filtered_5_0;
    if (!($grep_result_5_0 =~ m{\n\z}msx || $grep_result_5_0 eq q{})) {
    $grep_result_5_0 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_5_0 > 0 ? 0 : 1;
    $output_5 = $grep_result_5_0;
    $output_5 = $grep_result_5_0;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'failing_tests.txt'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_6 = q{};
    my @sed_lines_7 = split /\n/msx, $output_5;
    my @sed_result_7;
    foreach my $line (@sed_lines_7) {
    chomp $line;
    $line =~ s/^  FAIL: //gmsx;
    push @sed_result_7, $line;
    }
    $output_5 = join "\n", @sed_result_7;
    $tmp_redirect_6;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_5; }
    $output_printed_5 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    }
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '.last_trusted_count'
      or die "Cannot open file: $OS_ERROR\n";
    print $FAIL_COUNT;
if ( !( ($FAIL_COUNT) =~ m{\n\z}msx ) ) { print "\n"; }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    my $__echo_line = "Reset: failing_tests.txt has " . (do { my $_chomp_temp = do {
    my $wc_file = 'failing_tests.txt';
    my $wc_file_opened = 0;
    my $content = do {
        my $result = q{};
        if (open my $fh, '<', $wc_file) {
            $wc_file_opened = 1;
            local $INPUT_RECORD_SEPARATOR = undef;
            $result = <$fh>;
            close $fh or warn "Close failed: $OS_ERROR\n";
        } else {
            warn "Cannot open $wc_file: $OS_ERROR\n";
        }
        $result;
    };
    $wc_file_opened ? do {
        my $wc_lines = () = $content =~ /\n/gsxm;
        $wc_lines;
    } : q{};
}; chomp $_chomp_temp; $_chomp_temp; }) . " entries, .last_trusted_count = $FAIL_COUNT";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

exit $main_exit_code;
