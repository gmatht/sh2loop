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

my $OPTIONS;
my @OPTIONS;
my %OPTIONS;
my $apmopts;
my @apmopts;
my %apmopts;
my $raidstat;
my @raidstat;
my %raidstat;
my $DEVNAME;
my @DEVNAME;
my %DEVNAME;

$__set_e = 1;
if (!("$DEVNAME" ne q{})) {
    exit 1;
}
$main_exit_code = system('.', '/lib/hdparm/hdparm-functions') >> 8;
if ((-e '/proc/cmdline')) {
if (!(my $grep_result_0;
my @grep_lines_0 = ();
my @grep_filenames_0 = ();
if (-e "nohdparm") {
    open my $fh, '<', "nohdparm" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_0, $line;
        push @grep_filenames_0, "nohdparm";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: nohdparm: No such file or directory\n"; }
if (-e "/proc/cmdline") {
    open my $fh, '<', "/proc/cmdline" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_0, $line;
        push @grep_filenames_0, "/proc/cmdline";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cmdline: No such file or directory\n"; }
my @grep_filtered_0 = grep { /q/msx } @grep_lines_0;
$grep_result_0 = join "\n", @grep_filtered_0;
    if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
        $grep_result_0 .= "\n";
    }
print $grep_result_0;
$CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1)) {
exit 0;
    }
}
$raidstat = 'OK';
if ((-e '/proc/mdstat')) {
if (!(    $main_exit_code = system('egrep', '-iq', "resync|repair|recover|check", '/proc/mdstat') >> 8)) {
        $raidstat = 'RESYNC';
    }
}
else {
    if ((-e '/proc/rd/status')) {
        $raidstat = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/rd/status' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/rd/status' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    }
}
if (!(!("$raidstat" eq 'OK'))) {
exit 1;
}

sub die {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print $*;
if ( !( ($*) =~ m{\n\z}msx ) ) { print "\n"; }
    };
exit 1;
    return;
}
$OPTIONS = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'hdparm_options', $DEVNAME);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
if ($CHILD_ERROR != 0) {
        die("hdparm_options failed with: $OPTIONS");
}
$apmopts = q{};
if ("$OPTIONS" ne q{}) {
    my $opt;
    for my $opt ($OPTIONS) {
if ($opt =~ /^.*'-B'.*$/msx or $opt =~ /^.*'-S'.*$/msx or $opt =~ /^.*'force_spindown_time'.*$/msx) {
                        $apmopts = 'true';
        }
    }
if ("$apmopts" eq true) {
        $main_exit_code = system('/usr/lib/pm-utils/power.d/95hdparm-apm', 'resume') >> 8;
    }
    $OPTIONS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
        $output_2 .= $OPTIONS . "\n";
        if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
        my $perl_output_3 = do {
                        my $result = qx{perl '-p' q{e} "\"s/((-S|-B|force_spindown_time)[\\\\d]{1,3})|(-q\\\\s?)//g\""};
                        chomp $result;
                        $result;
                    };
        print $perl_output_3;
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_2 =~ s/\n+\z//msx;
        $output_2;
}; $_pipeline_result; };
if ("$OPTIONS" ne q{}) {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('/sbin/hdparm', '-q', $OPTIONS, $DEVNAME) >> 8;
        };
    }
}
exit 0;

exit $main_exit_code;
