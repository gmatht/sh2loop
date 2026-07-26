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

my $PATH;
my @PATH;
my %PATH;
$PATH = '/usr/sbin:';
my $unitdir;
my @unitdir;
my %unitdir;
$unitdir = "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem";
my $earlydir;
my @earlydir;
my %earlydir;
$earlydir = "/tmp";
if ("$2" ne q{}) {
    $earlydir = "$_[1]";
}

sub set_target {
symlink q{f}, "$earlydir/default.target" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    return;
}
if (!($main_exit_code = system('bash', 'selinuxenabled') >> 8)) {
if (!(my $grep_result_1;
my @grep_lines_1 = ();
my @grep_filenames_1 = ();
if (-e "/proc/cmdline") {
    open my $fh, '<', "/proc/cmdline" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_1, $line;
        push @grep_filenames_1, "/proc/cmdline";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cmdline: No such file or directory\n"; }
my @grep_filtered_1 = grep { /qE/msx } @grep_lines_1;
$grep_result_1 = join "\n", @grep_filtered_1;
    if (!($grep_result_1 =~ m{\n\z}msx || $grep_result_1 eq q{})) {
        $grep_result_1 .= "\n";
    }
print $grep_result_1;
$CHILD_ERROR = scalar @grep_filtered_1 > 0 ? 0 : 1)) {
exit 0;
    }
if ((-f '/.autorelabel')) {
        set_target();
}
    else {
        if (!(my $grep_result_2;
my @grep_lines_2 = ();
my @grep_filenames_2 = ();
if (-e "/proc/cmdline") {
    open my $fh, '<', "/proc/cmdline" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_2, $line;
        push @grep_filenames_2, "/proc/cmdline";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cmdline: No such file or directory\n"; }
my @grep_filtered_2 = grep { /qE/msx } @grep_lines_2;
$grep_result_2 = join "\n", @grep_filtered_2;
        if (!($grep_result_2 =~ m{\n\z}msx || $grep_result_2 eq q{})) {
            $grep_result_2 .= "\n";
        }
print $grep_result_2;
$CHILD_ERROR = scalar @grep_filtered_2 > 0 ? 0 : 1)) {
            set_target();
        }
    }
}

exit $main_exit_code;
