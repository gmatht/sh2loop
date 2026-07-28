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

my $test_input;
my @test_input;
my %test_input;
$test_input = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'mktemp', '/tmp/pvbench1XXXXXX');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
my $strace_output;
my @strace_output;
my %strace_output;
$strace_output = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'mktemp', '/tmp/pvbench2XXXXXX');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'rm -f ${test_input} ${strace_output} 2>&1'; print $end_out if $end_out ne q{}; }
my $pv;
my @pv;
my %pv;
$pv = (defined ${pv} && ${pv} ne q{} ? ${pv} : './pv');
$main_exit_code = system('test', '-x', ${pv}) >> 8;
if ($CHILD_ERROR != 0) {
        $pv = "pv";
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('dd', 'if', q{=}, '/dev/zero', 'of', q{=}, ${test_input}, 'bs', q{=}, '1k', 'count', q{=}, '1k') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
print "Buf(k)\tRate(k)\tReads\tRsize\tWrites\tWsize\n";
for (eval { int($ENV{buffer}=100) } // ""; eval { int($ENV{buffer}<=1000) } // ""; eval { int($ENV{buffer}+=100) } // "") {
        for (eval { int($ENV{rate}=100) } // ""; eval { int($ENV{rate}<=1000) } // ""; eval { int($ENV{rate}+=100) } // "") {
                my $rateparm;
                my @rateparm;
                my %rateparm;
                $rateparm = "-L " . ($ENV{rate} // q{}) . "k";
                if (do {
$main_exit_code = system('test', $rate, '-eq', q{0}) >> 8;
                    $CHILD_ERROR == 0
                }) {
                                        $rateparm = "";
                }
open STDIN, '<', ${test_input} or croak "Cannot open file: $OS_ERROR\n";
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('strace', '-tt', '-o', ${strace_output}, ${pv}, ${rateparm}, '-B', ($ENV{buffer} // q{}) . "k", '-f') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                my $rdata;
                my @rdata;
                my %rdata;
                $rdata = do { my @_qx_cmd = ('awk "\\$2~/^read\\\\(0,/{c++;t+=\\$NF}END{print c \\"\\\\t\\" t/c}" "${strace_output}"'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
                my $wdata;
                my @wdata;
                my %wdata;
                $wdata = do { my @_qx_cmd = ('awk "\\$2~/^write\\\\(1,/{c++;t+=\\$NF}END{print c \\"\\\\t\\" t/c}" "${strace_output}"'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
                do {
    my $__echo_line = "($ENV{buffer} // q{})\t($ENV{rate} // q{})\t${rdata}\t${wdata}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
        }
}

exit $main_exit_code;
