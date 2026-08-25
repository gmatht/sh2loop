#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use IPC::Open3;
my $main_exit_code = 0;
our $CHILD_ERROR = 0;
my $X = "test";
$ENV{X} = $X if exists $ENV{X};
if (!do { local $CHILD_ERROR; $CHILD_ERROR = 0;
0; $CHILD_ERROR }) {
        print "--x=${X}\n";
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
                $X = q{0};
    }
;
}
