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

my $resume_offset?;
my @resume_offset?;
my %resume_offset?;
my $DEV;
my @DEV;
my %DEV;
my $resume?;
my @resume?;
my %resume?;
my $MAJMIN;
my @MAJMIN;
my %MAJMIN;

my $PREREQ;
my @PREREQ;
my %PREREQ;
$PREREQ = "";

sub prereqs {
    print $PREREQ;
if ( !( ($PREREQ) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}
if ($arg1 =~ /^prereqs$/msx) {
        prereqs();
    exit 0;
}
if (("${resume?}" eq q{} || (!-e /sys/power/resume))) {
exit 0;
}
$main_exit_code = system('.', '/scripts/functions') >> 8;
$main_exit_code = system('.', '/scripts/local') >> 8;
my $PAGE_SIZE;
my @PAGE_SIZE;
my %PAGE_SIZE;
$PAGE_SIZE = '4096';
if ((-x '/bin/getconf')) {
    $PAGE_SIZE = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'getconf', 'PAGESIZE');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
}
$ENV{PAGE_SIZE} = $PAGE_SIZE;
if (!(!($main_exit_code = system('local_device_setup', ($ENV{resume} // q{}), "suspend/resume device", 'false') >> 8;))) {
exit 0;
}
$DEV = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'readlink', '-f', "$ENV{resume}");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
$DEV = '/sys/class/block/';
$CHILD_ERROR = 0;
if ((-r "$DEV")) {
open STDIN, '<', "$DEV" or croak "Cannot open file: $OS_ERROR\n";
$MAJMIN = <>;
chomp $MAJMIN;
$CHILD_ERROR = defined($MAJMIN) ? 0 : 1;
}
if ("$MAJMIN" eq q{}) {
exit 1;
}
if (!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
(${resume_offset?} >= 0)})) {
    my $offset_option;
    my @offset_option;
    my %offset_option;
    my $resume_offset;
    $offset_option = eval { int(${resume_offset?} * $PAGE_SIZE) } // "";
    my $SWAPTYPE;
    my @SWAPTYPE;
    my %SWAPTYPE;
    $SWAPTYPE = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'blkid', '-p', '-O', $offset_option, ($ENV{resume} // q{}), '-s', 'TYPE', '-o', 'value');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
    $MAJMIN = ${MAJMIN} . ":" . ${resume_offset?};
}
else {
    $SWAPTYPE = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'blkid', '-p', '-o', 'value', '-s', 'TYPE', "$ENV{resume}");
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
}
my $use_plymouth;
my @use_plymouth;
my %use_plymouth;
$use_plymouth = 'false';
if ((!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'plymouth') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
}) && !($main_exit_code = system('plymouth', '--ping') >> 8))) {
    $use_plymouth = 'true';
}
if (${SWAPTYPE} =~ /^swsuspend$/msx or ${SWAPTYPE} =~ /^s1suspend$/msx or ${SWAPTYPE} =~ /^s2suspend$/msx or ${SWAPTYPE} =~ /^ulsuspend$/msx or ${SWAPTYPE} =~ /^tuxonice$/msx) {
    if (!(    $CHILD_ERROR = 0)) {
        $main_exit_code = system('plymouth', 'message', '--text=Resuming from $resume') >> 8;
require Time::HiRes; Time::HiRes::sleep('0.1');
    }
} elsif (${SWAPTYPE} =~ /^swap$/msx) {
} elsif (1) {
    exit 0;
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/sys/power/resume'
      or die "Cannot open file: $OS_ERROR\n";
    print ${MAJMIN};
if ( !( (${MAJMIN}) =~ m{\n\z}msx ) ) { print "\n"; }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if (!($CHILD_ERROR = 0)) {
    $main_exit_code = system('plymouth', 'display-message', '--text=') >> 8;
}

exit $main_exit_code;
