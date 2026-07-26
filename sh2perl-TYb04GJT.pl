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
my $VERSION;
my @VERSION;
my %VERSION;
$VERSION = $_[1] =~ s/^python//r;
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'py3compile';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $main_exit_code = system('py3compile', '-V', $VERSION, '/usr/lib/python3/dist-packages') >> 8;
}
else {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
exit 1;
}

exit $main_exit_code;
