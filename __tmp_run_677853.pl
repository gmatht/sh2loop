#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use IPC::Open3;
my $main_exit_code = 0;
my $output = '';
our $CHILD_ERROR = 0;
print "Grep test:\n";
$CHILD_ERROR = 0;
# Original bash: echo "alpha beta gamma" | grep beta
my $output_0 = do { open(my $__fh, '-|', 'bash', '-c', q{echo 'alpha beta gamma' | grep beta}) or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_0 ne q{}) { print $output_0, "\n"; }
print "---\n";
$CHILD_ERROR = 0;
# Original bash: echo "alpha beta gamma" | grep -o beta
my $output_1 = do { open(my $__fh, '-|', 'bash', '-c', q{echo 'alpha beta gamma' | grep -o beta}) or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_1 ne q{}) { print $output_1, "\n"; }
print "done\n";
$CHILD_ERROR = 0;

exit ($main_exit_code || $CHILD_ERROR);
