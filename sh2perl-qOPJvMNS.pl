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

my $MAGIC_5   = 5;
my $MAGIC_111 = 111;

my $DDIR;
my @DDIR;
my %DDIR;
$DDIR = '../data';
my $GATE;
my @GATE;
my %GATE;
$GATE = '192.157.69.11';
my $UCMD;
my @UCMD;
my %UCMD;
$UCMD = 'nc -v -w 8';
if (do {
if (do {
$main_exit_code = system('test', q{!}, "$_[0]") >> 8;
    $CHILD_ERROR == 0
}) {
        print 'Needs' . q{ } . 'victim' . q{ } . 'arg' . "\n";
    $CHILD_ERROR = 0;
}
    $CHILD_ERROR == 0
}) {
    exit 1;
}
# Original bash: echo '' | $UCMD -w 9 -r "$1" 13 79 6667 2>&1
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= q{} . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_2 = 'unknown_command';
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', $cmd_2, '-w', q{9}, '-r', '13', '79', '6667');
    print {$in_1} $output_0;
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }
# Original bash: echo '0' | $UCMD "$1" 79 2>&1
{
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= q{0} . "\n";
if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_5 = 'unknown_command';
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', $cmd_5, '79');
    print {$in_4} $output_3;
    close $in_4 or croak 'Close failed: $OS_ERROR';
    $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    if ($output_3 ne q{} && !defined $output_printed_3) {
        print $output_3;
        if (!($output_3 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    }
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
# Original bash: echo 'UDP echoecho!' | nc -u -p 7 -s `hostname` -w 3 "$1" 7 19 2>&1
{
    my $output_6 = q{};
    my $output_printed_6;
    my $pipeline_success_6 = 1;
    $output_6 .= 'UDP echoecho!' . "\n";
if ( !($output_6 =~ m{\n\z}msx) ) { $output_6 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_8 = 'nc';
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', $cmd_8, '-u', '-p', q{7}, '-s', '-w', q{3}, q{7}, '19');
    print {$in_7} $output_6;
    close $in_7 or croak 'Close failed: $OS_ERROR';
    $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    if ($output_6 ne q{} && !defined $output_printed_6) {
        print $output_6;
        if (!($output_6 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
    }
# Original bash: echo '113,10158' | $UCMD -p 10158 "$1" 113 2>&1
{
    my $output_9 = q{};
    my $output_printed_9;
    my $pipeline_success_9 = 1;
    $output_9 .= '113,10158' . "\n";
if ( !($output_9 =~ m{\n\z}msx) ) { $output_9 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_11 = 'unknown_command';
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', $cmd_11, '-p', '10158', '113');
    print {$in_10} $output_9;
    close $in_10 or croak 'Close failed: $OS_ERROR';
    $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    if ($output_9 ne q{} && !defined $output_printed_9) {
        print $output_9;
        if (!($output_9 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
    }
# Original bash: rservice bin bin | $UCMD -p 1019 "$1" shell 2>&1
{
    my $output_12 = q{};
    my $output_printed_12;
    my $pipeline_success_12 = 1;
        my ($in_13, $out_13);
    my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'rservice', 'bin', 'bin');
    close $in_13 or croak 'Close failed: $OS_ERROR';
    $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
    close $out_13 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_13, 0;

        my $cmd_15 = 'unknown_command';
    my ($in_14, $out_14);
    my $pid_14 = open3($in_14, $out_14, '>&STDERR', $cmd_15, '-p', '1019', 'shell');
    print {$in_14} $output_12;
    close $in_14 or croak 'Close failed: $OS_ERROR';
    $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
    close $out_14 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_14, 0;
    if ($output_12 ne q{} && !defined $output_printed_12) {
        print $output_12;
        if (!($output_12 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
    }
# Original bash: echo QUIT | $UCMD -w 8 -r "$1" 25 158 159 119 110 109 1109 142-144 220 23 2>&1
{
    my $output_16 = q{};
    my $output_printed_16;
    my $pipeline_success_16 = 1;
    $output_16 .= 'QUIT' . "\n";
if ( !($output_16 =~ m{\n\z}msx) ) { $output_16 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_18 = 'unknown_command';
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', $cmd_18, '-w', q{8}, '-r', '25', '158', '159', '119', '110', '109', '1109', '142-144', '220', '23');
    print {$in_17} $output_16;
    close $in_17 or croak 'Close failed: $OS_ERROR';
    $output_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    if ($output_16 ne q{} && !defined $output_printed_16) {
        print $output_16;
        if (!($output_16 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
    }
$CHILD_ERROR = 0;
# Original bash: echo PASV | $UCMD -r "$1" 21 2>&1
{
    my $output_19 = q{};
    my $output_printed_19;
    my $pipeline_success_19 = 1;
    $output_19 .= 'PASV' . "\n";
if ( !($output_19 =~ m{\n\z}msx) ) { $output_19 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_21 = 'unknown_command';
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', $cmd_21, '-r', '21');
    print {$in_20} $output_19;
    close $in_20 or croak 'Close failed: $OS_ERROR';
    $output_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    if ($output_19 ne q{} && !defined $output_printed_19) {
        print $output_19;
        if (!($output_19 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
    }
# Original bash: echo 'GET /' | $UCMD -w 10 "$1" 80 81 210 70 2>&1
{
    my $output_22 = q{};
    my $output_printed_22;
    my $pipeline_success_22 = 1;
    $output_22 .= 'GET /' . "\n";
if ( !($output_22 =~ m{\n\z}msx) ) { $output_22 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_24 = 'unknown_command';
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', $cmd_24, '-w', '10', '80', '81', '210', '70');
    print {$in_23} $output_22;
    close $in_23 or croak 'Close failed: $OS_ERROR';
    $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    if ($output_22 ne q{} && !defined $output_printed_22) {
        print $output_22;
        if (!($output_22 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
    }
# Original bash: echo 'GET /robots.txt' | $UCMD -w 10 "$1" 80 2>&1
{
    my $output_25 = q{};
    my $output_printed_25;
    my $pipeline_success_25 = 1;
    $output_25 .= 'GET /robots.txt' . "\n";
if ( !($output_25 =~ m{\n\z}msx) ) { $output_25 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_27 = 'unknown_command';
    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', $cmd_27, '-w', '10', '80');
    print {$in_26} $output_25;
    close $in_26 or croak 'Close failed: $OS_ERROR';
    $output_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    if ($output_25 ne q{} && !defined $output_printed_25) {
        print $output_25;
        if (!($output_25 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
    }
# Original bash: rservice bin bin 9600/9600 | $UCMD -p 1020 "$1" login 2>&1
{
    my $output_28 = q{};
    my $output_printed_28;
    my $pipeline_success_28 = 1;
        my ($in_29, $out_29);
    my $pid_29 = open3($in_29, $out_29, '>&STDERR', 'rservice', 'bin', 'bin', '9600/9600');
    close $in_29 or croak 'Close failed: $OS_ERROR';
    $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
    close $out_29 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_29, 0;

        my $cmd_31 = 'unknown_command';
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', $cmd_31, '-p', '1020', 'login');
    print {$in_30} $output_28;
    close $in_30 or croak 'Close failed: $OS_ERROR';
    $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    if ($output_28 ne q{} && !defined $output_printed_28) {
        print $output_28;
        if (!($output_28 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
    }
# Original bash: rservice root root | $UCMD -r "$1" exec 2>&1
{
    my $output_32 = q{};
    my $output_printed_32;
    my $pipeline_success_32 = 1;
        my ($in_33, $out_33);
    my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'rservice', 'root', 'root');
    close $in_33 or croak 'Close failed: $OS_ERROR';
    $output_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
    close $out_33 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_33, 0;

        my $cmd_35 = 'unknown_command';
    my ($in_34, $out_34);
    my $pid_34 = open3($in_34, $out_34, '>&STDERR', $cmd_35, '-r', 'exec');
    print {$in_34} $output_32;
    close $in_34 or croak 'Close failed: $OS_ERROR';
    $output_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
    close $out_34 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_34, 0;
    if ($output_32 ne q{} && !defined $output_printed_32) {
        print $output_32;
        if (!($output_32 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
    }
print "BEGIN big udp -- everything may look \"open\" if packet-filtered\n";
# Original bash: data -g < ${DDIR}/nfs-0.d | $UCMD -i 1 -u "$1" 2049 | od -x 2>&1
{
    my $output_36 = q{};
    my $output_printed_36;
    my $pipeline_success_36 = 1;
        $output = q{};
    open STDIN, '<', $DDIR or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_37 = q{};

my $cmd_40 = 'data';
my ($in_39, $out_39);
my $pid_39 = open3($in_39, $out_39, '>&STDERR', $cmd_40, '-g', '/nfs-0.d');
print {$in_39} $output_36;
close $in_39 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_37 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_39> };
close $out_39 or croak 'Close failed: $OS_ERROR';
waitpid $pid_39, 0;
$tmp_redirect_37;
    $output_36 = $output;

        my $cmd_42 = 'unknown_command';
    my ($in_41, $out_41);
    my $pid_41 = open3($in_41, $out_41, '>&STDERR', $cmd_42, '-i', q{1}, '-u', '2049');
    print {$in_41} $output_36;
    close $in_41 or croak 'Close failed: $OS_ERROR';
    $output_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_41> };
    close $out_41 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_41, 0;

        my $cmd_44 = 'od';
    my ($in_43, $out_43);
    my $pid_43 = open3($in_43, $out_43, '>&STDERR', $cmd_44, '-x');
    print {$in_43} $output_36;
    close $in_43 or croak 'Close failed: $OS_ERROR';
    $output_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_43> };
    close $out_43 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_43, 0;
    if ($output_36 ne q{} && !defined $output_printed_36) {
        print $output_36;
        if (!($output_36 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_36 ) { $main_exit_code = 1; }
    }
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    $main_exit_code = system('nc', '-v', '-z', '-u', '-r', "$_[0]", '111', '66-70', '88', '53', '87', '161-164', '121-123', '213', '49') >> 8;
};
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    $main_exit_code = system('nc', '-v', '-z', '-u', '-r', "$_[0]", '137-140', '694-712', '747-770', '175-180', '2103', '510-530') >> 8;
};
print 'END big udp' . "\n";
$CHILD_ERROR = 0;
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    $main_exit_code = system('iscan', "$_[0]", '21', '25', '79', '80', '111', '53', '6667', '6000', '2049', '119') >> 8;
};
if (!($main_exit_code = system('nc', '-w', q{5}, '-z', '-u', "$_[0]", '111') >> 8)) {
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        $main_exit_code = system('showmount', '-e', "$_[0]") >> 8;
    };
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        $main_exit_code = system('rpcinfo', '-p', "$_[0]") >> 8;
    };
}
exit 0;

exit $main_exit_code;
