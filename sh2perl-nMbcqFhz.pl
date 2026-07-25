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

my $DRY_RUN;
my @DRY_RUN;
my %DRY_RUN;
my $REMOVE;
my @REMOVE;
my %REMOVE;

my $APPARMOR_FUNCTIONS;
my @APPARMOR_FUNCTIONS;
my %APPARMOR_FUNCTIONS;
$APPARMOR_FUNCTIONS = '/lib/apparmor/rc.apparmor.functions';
my $APPARMORFS;
my @APPARMORFS;
my %APPARMORFS;
$APPARMORFS = '/sys/kernel/security/apparmor';
my $PROFILES;
my @PROFILES;
my %PROFILES;
$PROFILES = ${APPARMORFS} . "/profiles";
$REMOVE = ${APPARMORFS} . "/.remove";
$DRY_RUN = q{0};
$main_exit_code = system('.', $APPARMOR_FUNCTIONS) >> 8;

sub usage {
    my $progname = "$PROGRAM_NAME";
    my $rc = "$_[0]";
    my $msg = "usage: " . ${progname} . " [options]\n\nRemove profiles unknown to the " . "sys" . "tem" . "

Options:
 -h, --help	Show this help message and exit
 -n		Dry run; don't remove profiles";
if (($rc != 0)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print $msg;
if ( !( ($msg) =~ m{\n\z}msx ) ) { print "\n"; }
        };
}
    else {
        print $msg;
if ( !( ($msg) =~ m{\n\z}msx ) ) { print "\n"; }
    }
    return;
}
if ((scalar(@ARGV) > 1)) {
    usage(q{1});
}
else {
    if ((scalar(@ARGV) == 1)) {
if (("$1" eq "-h" || "$1" eq "--help")) {
            usage(q{0});
}
        else {
            if ("$1" eq "-n") {
                $DRY_RUN = q{1};
}
            else {
                usage(q{1});
            }
        }
    }
}
if (!(!(open STDIN, '<', "$PROFILES" or croak "Cannot open file: $OS_ERROR\n";
my $IFS = q{};
$_ = <>;
chomp $_;
$CHILD_ERROR = defined($_) ? 0 : 1;))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: Unable to read apparmorfs profiles file\n";
    };
exit 1;
}
else {
    if ((!-w "$REMOVE")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "ERROR: Unable to write to apparmorfs remove file\n";
        };
exit 1;
    }
}
my $LOADED_PROFILES;
my @LOADED_PROFILES;
my %LOADED_PROFILES;
$LOADED_PROFILES = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', "$ENV{PARSER}", '-N', $PROFILE_DIRS);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
if ($CHILD_ERROR != 0) {
            my $ret;
        my @ret;
        my %ret;
        $ret = $?;
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print 'apparmor_parser exited with failure, aborting.' . "\n";
            $CHILD_ERROR = 0;
        };
}
# Original bash: echo "$LOADED_PROFILES" | awk '
{
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= $LOADED_PROFILES . "\n";
if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
$CHILD_ERROR = 0;

        my @lines = split /\n/msx, $output_2;
    my @result;
    foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    if (!(" ))) { next; }
    push @result, ($line . "\n");
    }
    push @result, (f("%s
    " . arr[key])
    } . "\n");
    $output_2 = join "", @result;

        my @sort_lines_2_2 = split /\n/msx, $output_2;
    my @sort_sorted_2_2 = sort @sort_lines_2_2;
    @sort_sorted_2_2 = reverse @sort_sorted_2_2;
    my $output_2_2 = join "\n", @sort_sorted_2_2;
    if ($output_2_2 ne q{} && !($output_2_2 =~ m{\n\z}msx)) {
    $output_2_2 .= "\n";
    }
    $output_2 = $output_2_2;
    $output_2 = $output_2_2;

        my @lines = split /\n/msx, $output_2;
    my $result_2_3 = q{};
    for my $line (@lines) {
    chomp $line;
    my $L = $line;
    if (($DRY_RUN != 0)) {
    do {
    my $__echo_line = "Would remove '" . ($ENV{profile} // q{}) . "'";
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
    $__echo_line .= "\n";
    }
    $output .= $__echo_line;
    };
    $CHILD_ERROR = 0;
    }
    else {
    do {
    my $__echo_line = "Removing '" . ($ENV{profile} // q{}) . "'";
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
    $__echo_line .= "\n";
    }
    $output .= $__echo_line;
    };
    $CHILD_ERROR = 0;
    do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', ${REMOVE}
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_3 = q{};
    $tmp_redirect_3 .= $profile . "\n";
    $CHILD_ERROR = 0;
    $tmp_redirect_3;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_2; }
    $output_printed_2 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    }
    }
    $output_2 = $result_2_3;
    if ($output_2 ne q{} && !defined $output_printed_2) {
        print $output_2;
        if (!($output_2 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    }


exit $main_exit_code;
