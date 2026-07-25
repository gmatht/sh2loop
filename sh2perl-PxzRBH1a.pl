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

sub is_merged {
    my $directories = "/bin /sbin /lib";
    my $dir;
    for my $dir ($directories) {
        if (!((-e "$DPKG_ROOT$dir"))) {
            next;        }
        if (!("$(readlink -f "$DPKG_ROOT$dir")" eq "$DPKG_ROOT/usr$dir")) {
            return q{1};        }
    }
    my $arch_directories = "/lib64 /lib32 /libo32 /libx32";
    for my $dir ($arch_directories) {
        if (!((-e "$DPKG_ROOT$dir"))) {
            next;        }
if ((do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'readlink', '-f', "$ENV{DPKG_ROOT}$dir");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; }) =~ /^$DPKG_ROOT/usr/lib".*$/msx) {
        } elsif (1) {
            return q{1};        }
    }
return q{0};
    return;
}

sub fail_if_unmerged {
if (!(    is_merged())) {
return;
    }
print "

******************************************************************************
*
* The udev package cannot be installed because this system does
* not have a merged /usr.
*
* Please install the usrmerge package to convert this system to merged-/usr.
*
* For more information please read https://wiki.debian.org/UsrMerge.
*
******************************************************************************


";
exit 1;
    return;
}
if ("$_[0]" =~ /^install$/msx or "$_[0]" =~ /^upgrade$/msx) {
        fail_if_unmerged();
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/udev', "254.3-1\\", q{~}, '--', "@ARGV") >> 8;

exit $main_exit_code;
