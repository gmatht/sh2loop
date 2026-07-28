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

my $VERSION;
my @VERSION;
my %VERSION;

$__set_e = 1;
$VERSION = $_[1] =~ s/^python//r;
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'py3clean';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
if ("$VERSION" eq 3.1) {
        require File::Find;
        File::Find::find(sub {     next unless $_ =~ /^.*\.py[co]$/msx;     print "$File::Find::name\n"; }, '/usr/lib/python3.1/dist-packages');
        require File::Find;
        File::Find::find(sub {     next unless $_ =~ /^.*\.py[co]$/msx;     print "$File::Find::name\n"; }, '/usr/lib/python3/dist-packages');
}
    else {
        $main_exit_code = system('py3clean', '-V', $VERSION, '/usr/lib/python3/dist-packages') >> 8;
    }
}
else {
if ("$VERSION" eq 3.1) {
        require File::Find;
        File::Find::find(sub {     next unless $_ =~ /^.*\.py[co]$/msx;     print "$File::Find::name\n"; }, '/usr/lib/python3.1/dist-packages');
}
    else {
        my $TAG = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'python', $VERSION, '-c', "import sys; print(sys.implementation.cache_tag)");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
        require File::Find;
        File::Find::find(sub {     print "$File::Find::name\n"; }, '/usr/lib/python3/dist-packages');
        require File::Find;
        File::Find::find(sub {     next unless $_ =~ /^__pycache__$/msx;     print "$File::Find::name\n"; }, '/usr/lib/python3/dist-packages');
    }
}

exit $main_exit_code;
