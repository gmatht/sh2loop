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

my $MAGIC_61 = 61;
my $MAGIC_22 = 22;

$main_exit_code = system('.', './setup-vars') >> 8;
$main_exit_code = system('.', './setup-utf8') >> 8;
my $width;
my @width;
my %width;
$width = '30';
while ( (!Variable("width", false, None) eq 61) ) {
    $CHILD_ERROR = 0;
    my $returncode;
    my @returncode;
    my %returncode;
    $returncode = $?;
if ($returncode =~ /^$DIALOG_OK$/msx) {
    } elsif (1) {
                $main_exit_code = system('.', './report-button') >> 8;
        exit $main_exit_code;
    }
    $width = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'expr', $width, q{+}, q{1});
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
}

exit $main_exit_code;
