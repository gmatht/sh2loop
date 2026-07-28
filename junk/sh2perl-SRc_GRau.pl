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

my $ROOTFSTYPE;
my @ROOTFSTYPE;
my %ROOTFSTYPE;
my $LOOPFSTYPE;
my @LOOPFSTYPE;
my %LOOPFSTYPE;

$__set_e = 1;
if ($_[0] =~ /^prereqs$/msx) {
    exit 0;
}
if (((("${ROOTFSTYPE}" eq ntfs || "${ROOTFSTYPE}" eq ntfs-3g) || "${LOOPFSTYPE}" eq ntfs) || "${LOOPFSTYPE}" eq ntfs-3g)) {
    $main_exit_code = system('modprobe', 'fuse') >> 8;
}
exit 0;

exit $main_exit_code;
