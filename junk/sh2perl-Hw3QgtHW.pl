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


sub get_vendor {
    my $origin = "$ENV{DPKG_ROOT}/etc/dpkg/origins/default";
    my $vendor;
if ("$DEB_VENDOR" ne q{}) {
        $vendor = "$ENV{DEB_VENDOR}";
}
    else {
        if ((-e "$origin")) {
            $vendor = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_0 = q{};
            my $output_printed_0;
            my $output_1 = q{};
            while (my $line = <>) {
                chomp $line;
                                $tr_result_1 = $line;
$tr_result_1 =~ tr/A-Z/a-z/;
$line = $tr_result_1;
            }
            $output_1; };
}; $_pipeline_result; };
        }
    }
    do {
    my $__echo_line = (defined ${vendor} && ${vendor} ne q{} ? ${vendor} : 'default');
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub check_merged_usr_via_aliased_dirs {
    my $vendor;
    $vendor = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'get_vendor');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
if ("$vendor" =~ /^debian$/msx) {
        return;    } elsif ("$vendor" =~ /^ubuntu$/msx) {
        return;    }
    my $d;
    for my $d ('/bin', '/sbin', '/lib', '/lib32', '/libo32', '/libx32', '/lib64') {
        my $linkname;
        my @linkname;
        my %linkname;
        $linkname = (do { my $_chomp_temp = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'readlink', $d);
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}; chomp $_chomp_temp; $_chomp_temp; });
if (("$linkname" eq "usr$d" || "$linkname" eq "/usr$d")) {
            do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                print "This " . "sys" . "tem" . " uses merged-usr-via-aliased-dirs, going behind dpkg's\n";
            };
            do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                print "back, breaking its core assumptions. This can cause silent file\n";
            };
            do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                print "overwrites and disappearances, and its general tools misbehavior.\n";
            };
            do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                print "See <https://wiki.debian.org/Teams/Dpkg/FAQ#broken-usrmerge>.\n";
            };
last;
        }
    }
    return;
}
check_merged_usr_via_aliased_dirs();

exit $main_exit_code;
