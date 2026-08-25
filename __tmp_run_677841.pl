#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
my $main_exit_code = 0;
my $output = '';
our $CHILD_ERROR = 0;
# Original bash: printf "c\na\nb\n" | sort
my $output_0 = do { open(my $__fh, '-|', 'bash', '-c', 'printf "c\\\\na\\\\nb\\\\n" | sort') or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_0 ne q{}) { print $output_0, "\n"; }
print("exit: " . $CHILD_ERROR, "\n");
$CHILD_ERROR = 0;

exit ($main_exit_code || $CHILD_ERROR);
